import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key, required this.onStart}) : super(key: key);

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFffeef8),
              Color(0xFFfff5f9),
              Color(0xFFfdf2f8),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // App Name at Top
                Padding(
                  padding: const EdgeInsets.only(top: 40.0, bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white, // white background
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 8,
                          ),
                        ),
                        //child: ClipOval(
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        //),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ChatMate',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFd63384), // Rose pink
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main Icon/Illustration
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Color(0xFFf8d7da).withOpacity(0.6), // Light pink background
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFFd63384).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          size: 50,
                          color: Color(0xFFd63384), // Rose pink
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Main Title
                      Text(
                        'พร้อมตอบทุกคำถาม\n24 ชั่วโมง',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color.fromARGB(255, 78, 68, 78), // Deep purple for contrast
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Description
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'สอบถามข้อมูลสินค้า ติดตามสถานะคำสั่งซื้อ หรือขอความช่วยเหลือด้านบริการ ทั้งหมดได้ในแอปเดียว',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6c757d), // Soft gray for readability
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Feature Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'ข้อมูล\nสินค้า',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.local_shipping_outlined,
                              title: 'ติดตาม\nสถานะ',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.support_outlined,
                              title: 'ความช่วย\nเหลือ',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Start Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0, top: 32.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFd63384), // Rose pink background
                        foregroundColor: Colors.white, // White text
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: Color(0xFFd63384).withOpacity(0.3),
                      ),
                      onPressed: onStart,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'เริ่มต้นใช้งาน',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: Colors.white, // White arrow icon
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeatureCard({required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8), // White with high opacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFf8d7da).withOpacity(0.8), // Light pink border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFd63384).withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Color(0xFFd63384), // Rose pink
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Color.fromARGB(255, 12, 12, 12), // Deep purple for contrast
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}