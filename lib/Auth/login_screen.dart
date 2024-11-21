import 'package:crypto_rates/Auth/signup_screen.dart';
import 'package:crypto_rates/screens/crypto_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'forgot_password.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  GlobalKey<FormState> authKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePass = true;
  bool loading = false;

  final auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);

    return SafeArea(
      child: Form(
        key: authKey,
        child: Scaffold(
          body: loading ? Center(
            child: CircularProgressIndicator() ) :
          SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical:  size.height * 0.1,),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Login to App',
                      style: TextStyle(
                        fontSize: size.width * 0.06,
                        fontWeight: FontWeight.bold,),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: size.width * 0.05),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.04),
                          spreadRadius: 0.2,
                          blurRadius: 9,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'email is required';
                        } else if (!value.toString().contains('@')) {
                          return 'enter a valid email';
                        } else if (!value.toString().contains('.com')) {
                          return 'enter a valid email';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.emailAddress,
                      controller: emailController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade400,
                          size: 28,),
                        hintText: 'Email',
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.018),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: size.width * 0.05),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.04),
                            spreadRadius: 0.2,
                            blurRadius: 9,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'password is required';
                          } else if (value.length < 6) {
                            return 'password should be at least 6 characters';
                          }
                          return null;
                        },
                        controller: passwordController,
                        obscureText: hidePass,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, size: 28, color:
                          Colors.blue),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                hidePass = !hidePass;
                              });
                            },
                            icon: Icon(
                              hidePass ? Icons.visibility : Icons.visibility_off,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          hintText: 'Password',
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.003),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ForgotPassword()));
                  },
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(size.width * 0.59,
                        size.height * 0.012, 0, size.height * 0.002),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color:
                       Colors.blue.shade400,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.026),
                GestureDetector(
                  onTap: signIn,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 0, horizontal: size.width * 0.064),
                    child: Container(
                      height: size.height * 0.066,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          'Log in',
                          style: TextStyle(fontSize: 17,
                              color: Colors.grey.shade100),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account?',
                      style: TextStyle(fontSize: size.width * 0.042,
                          color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => SignUp()));
                      },
                      child: Text(
                        '  Sign Up',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: size.width * 0.041,
                            color: Colors.blue
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future signIn() async {
    bool darkMode = Theme.of(context).brightness == Brightness.dark;

    if (authKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        loading = true;
      });

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );

        if (!mounted) return;
        setState(() {
          loading = false;
        });

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => CryptoListScreen()),
              (route) => false,
        );
      } on FirebaseAuthException catch(e) {
        print(e);
        if (!mounted) return;
        setState(() {
          loading = false;
        });
        //if(e.code == '	There is no existing user record corresponding to the provided identifier.'){
        showDialog(context: context, builder:(context){
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)
            ),
            title: Text(e.message.toString(),
                style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.048
                )),
            actions: [
              TextButton(onPressed: (){
                Navigator.pop(context);
              }, child:Text('OK',
                style: TextStyle(
                    color: darkMode? Colors.grey[300] : Colors.grey[900],
                    fontSize: 16
                ),))
            ],
          );
        });
      } } else {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }
}