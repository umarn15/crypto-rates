import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final emailController= TextEditingController();
  bool loading = false;


  Future passwordReset () async {

    TextStyle style = TextStyle(color: Colors.grey[200],
        fontSize: 17);

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
      setState(() {
        loading = false;
      });
      showDialog(context: context, builder: (context){
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)
          ),
          content: Text('Link has been sent to your email',
            style: TextStyle(
                fontSize: 18
            ),),
          actions: [
            TextButton(onPressed: (){
              Navigator.pop(context);
            }, child: Text('Ok', style: style,))
          ],
        );
      });
    } on FirebaseAuthException catch(e){
      setState(() {
        loading = false;
      });
      print(e);
      showDialog(context: context, builder: (context){
        return AlertDialog(
          backgroundColor: Colors.blue.shade600,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)
          ),
          content: Text(e.message.toString(),
            style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width * 0.048
            ),),
          actions: [
            TextButton(onPressed: (){
              Navigator.pop(context);
            }, child: Text('Ok',style: style))
          ],
        );
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    bool darkMode = Theme.of(context).brightness == Brightness.dark;
    var size = MediaQuery.sizeOf(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          elevation: 0,
          title: Padding(
            padding: EdgeInsets.only(left: 6.0),
            child: Text('Reset your Password',),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                size.width * 0.06,
                size.height * 0.138,
                size.width * 0.06,
                size.height * 0.057),
            child: Column(
              children: [
                Text('Enter your email below so we can send you a link',
                  style: TextStyle(
                    fontSize: 18,
                  ),),
                SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(
                      fontSize: 17
                  ),
                  keyboardType: TextInputType.emailAddress,
                  controller: emailController,
                  decoration: InputDecoration(hintText: 'Email',
                  ),),
                SizedBox(height: 10),
                MaterialButton(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: passwordReset,
                    child: Text('Reset Password',
                      style: TextStyle(
                          color: darkMode? Colors.grey [900] : Colors.white
                      ),),
                    color: Colors.blue)
              ],
            ),
          ),
        ),
      ),
    );
  }
}