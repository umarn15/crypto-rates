import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String userId;
  final String email;
  final String name;
  final Timestamp? createdAt;
  
  UserModel({
    required this.userId,
    required this.email,
    required this.name,
    this.createdAt,
  });

  factory UserModel.fromJson(dynamic map){
    return UserModel(
        userId: map['uid'] ?? '',
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        createdAt: map['createdAt'] ?? 0
    );
  }
}

Future<UserModel> getUserData() async {
  try{
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Future.error('');

    final snapshot = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    final data = snapshot.data() as Map<String, dynamic>;
    return UserModel.fromJson(data);
  } catch(e){
    return Future.error('');
  }
}