 // user_data.dart
 import 'package:flutter/material.dart';

 class UserData with ChangeNotifier{
   String? currentUserId;
   String? rememberedId;
   String? rememberedName;

   void clear(){
     currentUserId = null;
     rememberedId = null;
     rememberedName = null;
     notifyListeners();
   }

   void setUserData(String currentUserId, String? rememberedId, String? rememberedName){
     this.currentUserId = currentUserId;
     this.rememberedId = rememberedId;
     this.rememberedName = rememberedName;
     notifyListeners();
   }
 }