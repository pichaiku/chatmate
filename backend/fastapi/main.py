from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from google import genai
import json
import logging
import mysql.connector
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure Gemini API
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
model_name = os.getenv("MODEL")

# Database configuration
db_config = {
    'host': os.getenv("DB_HOST", "localhost"),
    'user': os.getenv("DB_USER", "root"),
    'password': os.getenv("DB_PASSWORD", ""),
    'database': os.getenv("DB_NAME", "chatbot_db")
}

def get_db_connection():
    return mysql.connector.connect(**db_config)

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, WebSocket] = {}

    async def connect(self, websocket: WebSocket, client_id: int):
        await websocket.accept()
        self.active_connections[client_id] = websocket

    def disconnect(self, client_id: int):
        if client_id in self.active_connections:
            del self.active_connections[client_id]

    async def send_message(self, message: str, client_id: int):
        if client_id in self.active_connections:
            await self.active_connections[client_id].send_text(message)

manager = ConnectionManager()

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: int):
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_text()
            if not data.strip():
                logger.warning("Ignoring empty WebSocket message from client %s", client_id)
                continue

            try:
                message_data = json.loads(data)
            except json.JSONDecodeError as e:
                logger.warning(
                    "Ignoring invalid WebSocket JSON from client %s "
                    "(message length: %s): %s",
                    client_id,
                    len(data),
                    e,
                )
                continue

            if (
                not isinstance(message_data, dict)
                or not isinstance(message_data.get('message_type'), str)
                or not isinstance(message_data.get('content'), str)
            ):
                logger.warning(
                    "Ignoring invalid WebSocket payload from client %s",
                    client_id,
                )
                continue

            logger.info(
                "Received WebSocket message from client %s (type: %s)",
                client_id,
                message_data['message_type'],
            )
            
            # Store user message in database
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT INTO chat_messages (customer_id, message_type, content, is_from_user)
                VALUES (%s, %s, %s, %s)
            """, (client_id, message_data['message_type'], message_data['content'], True))
            
            conn.commit()
            cursor.close()
            conn.close()

            # Process message with Gemini API
            if message_data['message_type'] == 'text':
                response = client.models.generate_content(
                    model=model_name,
                    contents=message_data['content'],
                )
                response_text = response.text
            else:
                # Handle media content (image, audio, video)
                response_text = "Media processing not implemented yet"

            # Store Gemini's response in database
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT INTO chat_messages (customer_id, message_type, content, is_from_user)
                VALUES (%s, %s, %s, %s)
            """, (client_id, 'text', response_text, False))
            
            conn.commit()
            response_id = cursor.lastrowid
            cursor.close()
            conn.close()

            # Send response back to client
            await manager.send_message(
                json.dumps({
                    'id': str(response_id),
                    'message_type': 'text',
                    'content': response_text,
                    'is_from_user': False,
                    'created_at': datetime.now().isoformat()
                }),
                client_id
            )
            logger.info("Sent WebSocket response to client %s", client_id)

    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception:
        logger.exception("Error in WebSocket connection for client %s", client_id)
        manager.disconnect(client_id)

@app.get("/api/chat/history/{customer_id}")
async def get_chat_history(customer_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    cursor.execute("""
        SELECT id, message_type, content, is_from_user, created_at
        FROM chat_messages
        WHERE customer_id = %s
        ORDER BY created_at ASC
    """, (customer_id,))
    
    messages = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return messages

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
    )