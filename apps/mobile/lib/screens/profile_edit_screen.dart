import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileEditScreen extends StatefulWidget {
  final String currentInterest; 
  const ProfileEditScreen({super.key, required this.currentInterest});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const int _maxUsername = 20;
  static const int _maxInterest = 100; // จำกัด 100 ตัวตามที่คุณต้องการ

  late TextEditingController _usernameCtrl;
  late TextEditingController _interestCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: 'Somtum');
    _interestCtrl = TextEditingController(text: widget.currentInterest);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildCustomAppBar(context),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08), 
                                blurRadius: 10, 
                                offset: const Offset(0, 4)
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              ValueListenableBuilder(
                                valueListenable: _usernameCtrl,
                                builder: (_, val, __) {
                                  return Row(
                                    children: [
                                      const Text(
                                        'Username', 
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Do not use your real name', 
                                        style: TextStyle(fontSize: 11, color: Color(0xFFD9453F)) // สีตามที่คุณกำหนด
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${val.text.length}/$_maxUsername', 
                                        style: const TextStyle(fontSize: 12, color: Colors.black)
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(controller: _usernameCtrl, maxLength: _maxUsername),
                              const SizedBox(height: 24),
                              ValueListenableBuilder(
                                valueListenable: _interestCtrl,
                                builder: (_, val, __) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Interest', 
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)
                                      ),
                                      Text(
                                        '${val.text.length}/$_maxInterest', 
                                        style: const TextStyle(fontSize: 12, color: Colors.black)
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(controller: _interestCtrl, maxLength: _maxInterest, maxLines: 5),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => Navigator.pop(context, _interestCtrl.text),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDEF1C2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFC7D2B5), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1), 
                                  blurRadius: 4, 
                                  offset: const Offset(0, 2)
                                )
                              ],
                            ),
                            child: const Text(
                              'Save', 
                              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF695959), 
        borderRadius: BorderRadius.vertical(top: Radius.circular(35))
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08), 
                        blurRadius: 10, 
                        offset: const Offset(0, 4)
                      )
                    ],
                  ),
                  child: Image.asset('assets/images/Back.png', width: 26, height: 26),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Profile Edit', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required int maxLength, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black), // สีตัวหนังสือตอนพิมพ์เป็นสีดำ
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Colors.grey, width: 1.5)
        ),
      ),
    );
  }
}