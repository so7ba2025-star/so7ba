import 'package:flutter/material.dart';
'../../core/services/game_rules_service.dart';

class GameRulesScreen extends StatelessWidget {
  const GameRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قوانين لعبة الدومينو', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
        ),
        body: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.blue[50]!, Colors.blue[100]!],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('🎲 بداية اللعبة'),
                _buildRuleItem('• يتم خلط جميع قطع الدومينو (28 قطعة) ووضعها مقلوبة على الطاولة.'),
                _buildRuleItem('• كل لاعب يسحب 7 قطع عشوائياً (في حالة اللعب باثنين).'),
                _buildRuleItem('• يبدأ اللاعب الذي يملك القطعة المزدوجة الأكبر (6/6).'),
                _buildRuleItem('• إذا لم تكن 6/6 متوفرة، نبدأ ب 5/5، ثم 4/4، وهكذا.'),
                _buildRuleItem('• إذا لم تكن هناك قطع مزدوجة، يبدأ صاحب القطعة الأكبر.'),
                
                const SizedBox(height: 16),
                _buildSectionTitle('🃏 طريقة اللعب'),
                _buildRuleItem('1. يبدأ اللاعب الأول بوضع القطعة المزدوجة الأكبر في المنتصف.'),
                _buildRuleItem('2. الدور ينتقل للاعب التالي في اتجاه عقارب الساعة.'),
                _buildRuleItem('3. على كل لاعب وضع قطعة مناسبة بحيث:'),
                _buildRuleItem('   • تتطابق إحدى نهايتي القطعة مع نهاية سلسلة الدومينو.'),
                _buildRuleItem('   • إذا كانت القطعة تحتاج للدوران (قلب) لتتناسب، فيجب تدويرها.'),
                _buildRuleItem('4. إذا لم يكن لدى اللاعب قطعة مناسبة، يجب عليه سحب قطعة من الكومة.'),
                _buildRuleItem('5. إذا لم تكن هناك قطع متبقية للرسم، يتم تخطي دور اللاعب.'),
                
                const SizedBox(height: 16),
                _buildSectionTitle('🏁 نهاية الجولة'),
                _buildRuleItem('• تنتهي الجولة عندما:'),
                _buildRuleItem('  1. يلعب أحد اللاعبين آخر قطعة لديه (يفوز بالجولة).'),
                _buildRuleItem('  2. لا يستطيع أي لاعب لعب أي قطعة (اللعبة مقفولة).'),
                
                const SizedBox(height: 16),
                _buildSectionTitle('🏆 احتساب النقاط'),
                _buildRuleItem('• عند انتهاء الجولة، يحسب كل لاعب مجموع النقاط المتبقية في يده.'),
                _buildRuleItem('• الفائز بالجولة يسجل مجموع نقاط جميع اللاعبين الآخرين.'),
                _buildRuleItem('• أول من يصل إلى 100 نقطة (أو أي مجموع متفق عليه) يفوز بالمباراة.'),
                
                const SizedBox(height: 16),
                _buildSectionTitle('💡 استراتيجيات الفوز'),
                _buildRuleItem('• تخلص من القطع ذات القيم العالية أولاً.'),
                _buildRuleItem('• احتفظ بقطع متعددة من نفس الرقم للتحكم في اللعبة.'),
                _buildRuleItem('• راقب قطع الخصوم وحاول إجبارهم على السحب.'),
                _buildRuleItem('• استخدم القطع المزدوجة بحكمة حيث يصعب لعبها لاحقاً.'),
                
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('ابدأ اللعب', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      // TODO: التنقل إلى شاشة اللعب
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, height: 1.5),
        textAlign: TextAlign.right,
      ),
    );
  }
}
