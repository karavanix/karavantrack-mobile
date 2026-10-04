# WorkManager (pulled in by flutter_background_geolocation) opens its Room
# database via the generated WorkDatabase_Impl no-arg constructor. Room
# 2.6.1's consumer rule keeps the class but not the constructor, which R8
# full mode then strips: release crashed on start with NoSuchMethodException
# WorkDatabase_Impl.<init>. Room 2.7+ ships this rule itself.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
