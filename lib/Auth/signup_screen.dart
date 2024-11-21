import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto_rates/screens/crypto_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  GlobalKey<FormState> keyPass= GlobalKey<FormState>();
  final nameController = TextEditingController();
  final newEmailController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPassController = TextEditingController();

  final usersRef = FirebaseFirestore.instance.collection('Users');

  bool hidePass = true;
  bool confirmPass = true;
  bool loading = false;

  final auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    bool darkMode = Theme.of(context).brightness == Brightness.dark;
    var size = MediaQuery.sizeOf(context);

    return SafeArea(
      child: Form(
        key: keyPass,
        child: Scaffold(
          body: loading ? Center(
            child: CircularProgressIndicator()
          ) :
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: size.height * 0.1),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Register account',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.058,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.035),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'provide a name';
                      }
                      return null;
                    },
                    controller: nameController,
                    maxLength: 20,
                    decoration: InputDecoration(
                        hintText: 'Name',
                        counterText: '',
                        prefixIcon: Icon(Icons.person_outlined, size: 28, color:
                        darkMode? Colors.white :  Colors.blue[400],)
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: MediaQuery.of(context).size.width * 0.05),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'provide an email';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    controller: newEmailController,
                    decoration: InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 28, color:
                        darkMode? Colors.white : Colors.blue[400],)
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: MediaQuery.of(context).size.width * 0.05),
                  child: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'provide a password';
                      } else if (value.length < 6) {
                        return 'password should be at least 6 characters';
                      }
                      return null;
                    },
                    controller: newPasswordController,
                    obscureText: hidePass,
                    decoration: InputDecoration(
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              hidePass = !hidePass;
                            });
                          },
                          icon: Icon(
                            hidePass ? Icons.visibility : Icons.visibility_off,
                            color: darkMode? Colors.white : Colors.blue[400],
                          ),
                        ),
                        hintText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, size: 28, color:
                        darkMode? Colors.white : Colors.blue[400],)
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.032),
                GestureDetector(
                  onTap: () {
                    signUp();
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 0, horizontal: MediaQuery.of(context).size.width * 0.06),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.066,
                      decoration: BoxDecoration(
                        color: darkMode? Colors.white : Colors.blue[400],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          'Create account',
                          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.048, color:
                          darkMode? Colors.grey[900] :  Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.042,
                          color: darkMode? Colors.grey : Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginScreen()), (route) => false);
                      },
                      child: Text(
                        '  Log In',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.of(context).size.width * 0.042,
                            color: darkMode? Colors.white : Colors.blue
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

  Future signUp() async {
    bool darkMode = Theme.of(context).brightness == Brightness.dark;
    if (keyPass.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        loading = true;
      });

      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: newEmailController.text,
          password: newPasswordController.text,
        );

        String userId = FirebaseAuth.instance.currentUser!.uid;
        String username = nameController.text;
        String email = newEmailController.text;


          await usersRef.doc(userId).set({
            'name': username,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'uid': userId,
          });

        if (!mounted) return;
        setState(() {
          loading = false;
        });

        Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (context) => CryptoListScreen()),
              (route) => false,
        );
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        setState(() {
          loading = false;
        });
        showDialog(context: context, builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)
            ),
            title: Text(error.message.toString(),
              style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.048
              ),),
            actions: [
              TextButton(onPressed: () {
                Navigator.pop(context);
              }, child: Text('OK',
                style: TextStyle(
                    color:   darkMode? Colors.grey[300] : Colors.grey[900],
                    fontSize: 16
                ),))
            ],
          );
        });
      }
    }  else {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }
}