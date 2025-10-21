import 'package:flutter/material.dart';

class ChallengeIntroScreen extends StatelessWidget {
  const ChallengeIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 20) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF013328),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "챌린지 가이드",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Kopub',
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChallengeIntroBanner(context),
                  const SizedBox(height: 24),
                  _buildChallengeFlowGuide(),
                  const SizedBox(height: 24),
                  _buildChallengeTypeGuide(),
                  const SizedBox(height: 24),
                  _buildChallengeMethodGuide(),
                  const SizedBox(height: 24),
                  _buildChallengePeriodGuide(),
                  const SizedBox(height: 24),
                  _buildChallengeCheckGuide(),
                  const SizedBox(height: 100),
                ],
              ),
           ),
           _buildFloatingConfirmButton(context),
          ],
        ),
       ),
    );
  }

  Widget _buildChallengeIntroBanner(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ 배경 이미지
          Image.asset(
            'assets/image/image2.png',
            width: screenWidth,
            height: screenWidth * 0.5,
            fit: BoxFit.cover,
          ),

          // ✅ 반투명 블러 배경 + 텍스트
          Container(
            width: double.infinity,
            height: screenWidth * 0.5,
            color: Colors.black.withOpacity(0.4),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "챌린지란?",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'kopub',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "읽고, 기록하고, 성장하는 여정을 함께하는 독서 미션!\n"
                      "지금 바로 나에게 맞는 챌린지를 선택해\n새로운 독서 여정을 시작해보세요!",
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'kopub',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeTypeBanners(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final spacing = screenWidth * 0.04; // 4% 여백

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTypeBanner(
            imagePath: 'assets/image/routine_banner.jpg',
            title: '루틴형 챌린지',
            description: "습관을 만들고 싶어요!\n\n매일 또는 주기적으로 실천하며 책을 가까이 하는 습관을 만드는 챌린지입니다.\n",
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: _buildTypeBanner(
            imagePath: 'assets/image/growth_banner.jpg',
            title: '성장형 챌린지',
            description: "성장을 하고 싶어요!\n\n특정 도서나 특정 분야를 정해 독서하며 성장을 이루는 챌린지입니다.\n",
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBanner({
    required String imagePath,
    required String title,
    required String description,
  }) {
    return AspectRatio(
      aspectRatio: 0.7, // ✅ 너비 대비 적당한 높이 비율
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              imagePath,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      fontFamily: 'kopub',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'kopub',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Kopub',
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDescription(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontFamily: 'Kopub',
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  // 📌 챌린지 진행 순서 안내
  Widget _buildChallengeFlowGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("📌 챌린지 진행 순서"),
        const SizedBox(height: 12),
        _buildFlowStepBox("1️⃣", "챌린지 선택", "나에게 맞는 챌린지를 찾아 도전해보세요."),
        _buildFlowStepBox("2️⃣", "목표 설정", "도전 기간과 목표를 설정해 시작할 준비를 해요."),
        _buildFlowStepBox("3️⃣", "도전 시작", "책을 읽고 도전을 실천해요."),
        _buildFlowStepBox("4️⃣", "진행 기록 & 확인", "독서 기록을 남기며 도전 상태를 확인해요."),
        _buildFlowStepBox("5️⃣", "챌린지 완료 & 리워드 획득", "목표를 달성하고 특별한 리워드를 받아보세요!"),
      ],
    );
  }

  Widget _buildFlowStepBox(String emojiNumber, String title, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            emojiNumber,
            style: const TextStyle(
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📌 챌린지 유형 안내
  Widget _buildChallengeTypeGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("🎯 어떤 챌린지를 할까요?"),
        const SizedBox(height: 12),
        _buildQuestionCard(
          title: "🌀 매일 책을 가까이 하고 싶나요?",
          subtitle: "👉 루틴형 챌린지 추천",
        ),
        _buildQuestionCard(
          title: "🚀 목표를 완수하며 성장하고 싶나요?",
          subtitle: "👉 성장형 챌린지 추천",
        ),
      ],
    );
  }

  Widget _buildQuestionCard({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.amberAccent, fontSize: 14)),
        ],
      ),
    );
  }

  // 📌 챌린지 방법 안내
  Widget _buildChallengeMethodGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("⚙️ 도전 방법"),
        const SizedBox(height: 12),
        _buildListItem("📝 지정 횟수 도전 - 예) 7일간 5회"),
        _buildListItem("📚 지정 도서 도전 - 예) 철학 시리즈 완독"),
        _buildListItem("📖 지정 권수 도전 - 예) 한 달 3권 완독"),
      ],
    );
  }

  // 📌 챌린지 기간 안내
  Widget _buildChallengePeriodGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("⏳ 도전 기간"),
        const SizedBox(height: 12),
        _buildListItem("📅 기간형 - 정해진 시작일과 종료일이 있는 도전"),
        _buildListItem("📅 일자형 - 참여일 기준 N일간 도전"),
        _buildListItem("🔄 지속형 - 언제든지 도전 가능, 끝없이 반복 가능"),
      ],
    );
  }

  // 📌 체크 방식 안내
  Widget _buildChallengeCheckGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("✅ 체크 방식"),
        const SizedBox(height: 12),
        _buildListItem("✋ 수동 체크 - 스스로 체크 (루틴형 챌린지)"),
        _buildListItem("🤖 자동 체크 - 서재 기록과 연동 (성장형 챌린지)"),
      ],
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Kopub'),
      ),
    );
  }

  // ✅ 고정 확인 버튼
  Widget _buildFloatingConfirmButton(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40.0),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: ElevatedButton(
    onPressed: () => Navigator.pop(context),

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("이해했어요!",
                style: TextStyle(
                    fontSize: 18, fontFamily: 'kopub', fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required String description}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.amberAccent,
              fontFamily: 'Kopub',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Kopub',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
