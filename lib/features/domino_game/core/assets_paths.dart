// ثوابت مسارات صور الدومينو لوحدة لعبة الدومينو المصري الرباعي

/// إرجاع مسار صورة حجر دومينو بناءً على القيمتين اليسرى واليمنى.
String dominoTile(int left, int right) =>
    'assets/Domino_tiels/domino_${left}_${right}.png';

/// مسار صورة ظهر حجر الدومينو للاعب.
const String dominoBack = 'assets/Domino_tiels/domino_back.png';

/// مسار صورة ظهر حجر الدومينو للذكاء الاصطناعي / الخصم.
const String dominoBackAi = 'assets/Domino_tiels/domino_back_ai.png';
