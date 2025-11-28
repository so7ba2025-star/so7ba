import 'package:flutter/material.dart';

// ثوابت عامة لوحدة لعبة الدومينو المصري الرباعي.

// ألوان أساسية للعبة
const Color dominoBackgroundColor = Color(0xFFF5F0E6);
const Color dominoBorderColor = Color(0xFFD7CDBE);
const Color dominoDotColor = Colors.black;

// ألوان واجهة اللعبة (يمكن استخدامها لاحقًا في الـ UI)
const Color dominoTableBackground = Color(0xFF14532D); // أخضر غامق يشبه طاولة اللعب
const Color dominoPlayerAreaBackground = Color(0xFF0F172A); // منطقة اللاعب
const Color dominoAiAreaBackground = Color(0xFF111827); // منطقة الخصم / الـ AI

// أبعاد عامة لأحجار الدومينو في الواجهة (نسب تقريبية، قابلة للتعديل لاحقًا)
const double dominoTileAspectRatio = 2.0; // العرض : الارتفاع ~ 2:1
const double dominoTileBorderRadius = 12.0;
const double dominoTileElevation = 4.0;

// قيم ثابتة خاصة باللعبة
const int dominoMinValue = 0;
const int dominoMaxValue = 6; // دومينو مصري تقليدي 0-6
const int dominoTilesPerPlayer = 7; // القيمة الافتراضية يمكن تعديلها حسب القواعد لاحقًا

// أسماء يمكن استخدامها كمفاتيح تخزين محلي أو معرفات داخلية
const String dominoPrefsNamespace = 'domino_game';
const String dominoPrefsSoundEnabled = 'sound_enabled';
const String dominoPrefsVibrationEnabled = 'vibration_enabled';
const String dominoPrefsLastDifficulty = 'last_difficulty';
