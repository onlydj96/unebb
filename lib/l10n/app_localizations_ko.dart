// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'UnEbb';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get save => '저장';

  @override
  String get start => '시작';

  @override
  String get errorGeneric => '문제가 발생했습니다. 다시 시도해 주세요.';

  @override
  String get errorNetwork => '인터넷 연결을 확인한 뒤 다시 시도해 주세요.';

  @override
  String get errorSessionExpired => '로그인이 만료되었습니다. 다시 로그인해 주세요.';

  @override
  String get errorAiUnavailable => 'AI 서비스가 지금 응답하지 않습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorClockSync =>
      '기기 시간이 맞지 않습니다. 날짜 및 시간을 자동으로 설정한 뒤 다시 시도해 주세요.';

  @override
  String get errorRateLimited => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get offlineBanner => '오프라인 상태입니다. 저장된 데이터를 표시합니다.';

  @override
  String get offlineActionRequired => '인터넷 연결이 필요합니다.';

  @override
  String get refreshFailed => '새로고침하지 못했습니다. 저장된 데이터를 표시합니다.';

  @override
  String get navHome => '홈';

  @override
  String get navDecks => '덱';

  @override
  String get navSettings => '설정';

  @override
  String get dashboardGreeting => '오늘도 학습해 볼까요?';

  @override
  String get dashboardSubtitle => '복습으로 기억을 단단하게 만들어 보세요.';

  @override
  String get startReview => '복습 시작';

  @override
  String wordsDue(int count) {
    return '복습할 단어 $count개';
  }

  @override
  String get nothingDue => '복습할 단어가 없어요. 전체 복습으로 감을 유지해 보세요!';

  @override
  String get yourProgress => '학습 현황';

  @override
  String get statDecks => '덱';

  @override
  String get statWords => '단어';

  @override
  String get statMastered => '마스터';

  @override
  String get recentDecks => '최근 덱';

  @override
  String get seeAll => '전체 보기';

  @override
  String get noDecksYet => '아직 덱이 없어요';

  @override
  String get createFirstDeck => '첫 덱을 만들어 학습을 시작해 보세요!';

  @override
  String get createDeck => '덱 만들기';

  @override
  String wordCount(int count) {
    return '$count개 단어';
  }

  @override
  String get reviewOptionsTitle => '복습 시작';

  @override
  String get deckReviewTitle => '덱 복습';

  @override
  String get reviewWhichWords => '어떤 단어를 복습하시겠어요?';

  @override
  String get reviewDueOnly => '복습 시간이 된 단어만';

  @override
  String get reviewAllWords => '모든 단어';

  @override
  String get reviewAllWordsSubtitle => '새 단어와 약한 단어부터';

  @override
  String get reviewHowMany => '몇 개의 단어를 복습할까요?';

  @override
  String get quickSelect => '빠른 선택';

  @override
  String get review => '복습';

  @override
  String get voiceMode => '음성 모드';

  @override
  String get voiceModeEnabled => '음성 모드 활성화됨';

  @override
  String get voiceModeDisabled => '음성 모드 비활성화됨';

  @override
  String get speakingWord => '단어 읽는 중...';

  @override
  String get listeningForMeaning => '듣는 중... 뜻을 설명해주세요';

  @override
  String get listeningForTranslation => '듣는 중... 문장을 번역해주세요';

  @override
  String get tapMicToSpeak => '마이크를 탭해서 말하기';

  @override
  String get processing => '처리 중...';

  @override
  String get voiceModeInitFailed => '음성 모드 초기화 실패. 마이크 권한을 확인해주세요.';

  @override
  String get speakNow => '지금 말하세요';

  @override
  String get tapToStopListening => '탭해서 듣기 중지';

  @override
  String get tapToAnswer => '탭해서 답하기';

  @override
  String get doYouKnowThisWord => '이 단어를 아시나요?';

  @override
  String get sayYesOrNo => '네 또는 아니오로 대답하세요';

  @override
  String get listeningForYesNo => '듣는 중... 네 또는 아니오';

  @override
  String get iKnowIt => '알아요';

  @override
  String get iDontKnowIt => '몰라요';

  @override
  String get explainTheMeaning => '뜻을 설명해주세요';

  @override
  String get whatIsTheMeaning => '이 단어의 뜻은?';

  @override
  String get enterMeaningHint => '뜻을 입력하세요 (예: 인접한)';

  @override
  String get submitAnswer => '답변 제출';

  @override
  String get checkingYourAnswer => '답변 확인 중…';

  @override
  String get correctMeaning => '올바른 의미';

  @override
  String get nextWord => '다음 단어';

  @override
  String get preparingTranslationExercise => '번역 문제 준비 중…';

  @override
  String translateInto(String language) {
    return '$language로 번역하세요';
  }

  @override
  String hintUseWord(String word) {
    return '힌트: \"$word\" 사용';
  }

  @override
  String yourTranslationHint(String language) {
    return '$language 번역…';
  }

  @override
  String get submitTranslation => '번역 제출';

  @override
  String get evaluatingYourTranslation => '번역 평가 중…';

  @override
  String get generatingExplanation => '설명 생성 중…';

  @override
  String get wordExplanation => '단어 설명';

  @override
  String get definition => '정의';

  @override
  String get explanation => '설명';

  @override
  String get examples => '예문';

  @override
  String get synonyms => '동의어';

  @override
  String get collocations => '연어';

  @override
  String get commonMistakes => '흔한 실수';

  @override
  String get gotIt => '알겠어요';

  @override
  String get tapToReveal => '탭해서 보기';

  @override
  String get meaning => '의미';

  @override
  String get usage => '사용법';

  @override
  String get translation => '번역';

  @override
  String get wordUsage => '단어 활용';

  @override
  String get naturalness => '자연스러움';

  @override
  String get grammar => '문법';

  @override
  String get patternsToWatch => '주의할 패턴';

  @override
  String focusArea(String point) {
    return '집중할 부분: $point';
  }

  @override
  String get memoryStrong => '강함';

  @override
  String get memoryGood => '양호';

  @override
  String get memoryWeak => '약함';

  @override
  String get memoryCritical => '위험';

  @override
  String get allCaughtUp => '모두 완료!';

  @override
  String get noDueWords => '현재 복습할 단어가 없습니다.\n나중에 다시 오거나 새 단어를 추가하세요.';

  @override
  String get reviewAllInstead => '전체 단어 복습하기';

  @override
  String get back => '뒤로';

  @override
  String get sessionComplete => '세션 완료!';

  @override
  String correctOutOf(int correct, int total) {
    return '$total개 중 $correct개 정답';
  }

  @override
  String get done => '완료';

  @override
  String get retry => '재시도';

  @override
  String get skipWord => '건너뛰기';

  @override
  String get finish => '종료';

  @override
  String get aiContentMissing => '이 단어의 AI 설명을 아직 불러오지 못했어요.';

  @override
  String get resumeSession => '세션 이어하기';

  @override
  String get resumeSessionTitle => '이전 세션을 이어서 하시겠습니까?';

  @override
  String resumeSessionMessage(int remaining, int completed) {
    return '완료되지 않은 복습 세션이 있습니다. $remaining개의 단어가 남아있습니다 ($completed개 완료됨).';
  }

  @override
  String get continueSession => '이어하기';

  @override
  String get startNewSession => '새로 시작';

  @override
  String get myDecks => '내 덱';

  @override
  String get errorLoadingDecks => '덱을 불러오지 못했습니다.';

  @override
  String get noDecksDescription => '첫 덱을 만들어 단어를 정리해 보세요.';

  @override
  String get deleteDeckTitle => '덱을 삭제할까요?';

  @override
  String deleteDeckMessage(String name) {
    return '\"$name\" 덱과 모든 단어가 삭제됩니다. 되돌릴 수 없습니다.';
  }

  @override
  String get deleteFailed => '삭제하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get deckNotFound => '덱을 찾을 수 없습니다';

  @override
  String get noWordsYet => '아직 단어가 없어요';

  @override
  String get addFirstWordToDeck => '이 덱에 첫 단어를 추가해 보세요.';

  @override
  String get addWord => '단어 추가';

  @override
  String get deckName => '덱 이름';

  @override
  String get deckNameHint => '예: 토익 단어';

  @override
  String get deckNameRequired => '덱 이름을 입력해 주세요';

  @override
  String get deckDescription => '설명 (선택)';

  @override
  String get deckDescriptionHint => '어떤 용도의 덱인가요?';

  @override
  String duplicateDeckName(String name) {
    return '\"$name\" 덱이 이미 있습니다.';
  }

  @override
  String get language => '언어';

  @override
  String get learningLanguage => '학습 언어';

  @override
  String get nativeLanguage => '모국어';

  @override
  String get allWords => '전체 단어';

  @override
  String get noWordsHint => '아직 단어가 없어요.\n첫 단어를 추가해 보세요.';

  @override
  String get errorLoadingWords => '단어를 불러오지 못했습니다.';

  @override
  String get wordOrPhrase => '단어 또는 표현';

  @override
  String get wordHintExample => '예: ephemeral';

  @override
  String get wordRequired => '단어를 입력해 주세요';

  @override
  String get editWord => '단어 수정';

  @override
  String get saveChanges => '변경 사항 저장';

  @override
  String get deleteWordTitle => '단어를 삭제할까요?';

  @override
  String deleteWordMessage(String word) {
    return '\"$word\"을(를) 단어장에서 삭제할까요? 되돌릴 수 없습니다.';
  }

  @override
  String get wordNotFound => '단어를 찾을 수 없습니다.';

  @override
  String get wordDetail => '단어 상세';

  @override
  String get aiGenerating => 'AI 설명을 생성하는 중…';

  @override
  String get aiFailed => 'AI 설명을 생성하지 못했습니다.';

  @override
  String get aiMissing => '아직 AI 설명이 없는 단어입니다.';

  @override
  String get generateExplanation => '설명 생성';

  @override
  String get feedback => '피드백';

  @override
  String get wordAddedTitle => '단어 추가됨';

  @override
  String wordAddedSuccess(String word) {
    return '\"$word\"이(가) 단어장에 추가되었습니다!';
  }

  @override
  String get practiceNow => '바로 연습하기';

  @override
  String duplicateWordError(String word) {
    return '\"$word\"은(는) 이 단어장에 이미 있습니다.';
  }

  @override
  String duplicateWordInDeck(String word, String deck) {
    return '\"$word\"은(는) 이미 \"$deck\" 덱에 있습니다.';
  }

  @override
  String get duplicateWordErrorGeneral => '이 단어는 단어장에 이미 있습니다.';

  @override
  String get tagline => '기억에 맞춘 단어 학습';

  @override
  String get signIn => '로그인';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get noAccountSignUp => '계정이 없으신가요? 회원가입';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get emailInvalid => '올바른 이메일 주소를 입력해 주세요';

  @override
  String get passwordTooShort => '비밀번호는 6자 이상이어야 합니다';

  @override
  String get checkEmailToConfirm => '이메일에서 계정을 인증한 뒤 로그인해 주세요.';

  @override
  String get invalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get emailNotConfirmed => '먼저 이메일 인증을 완료해 주세요.';

  @override
  String get userAlreadyExists => '이미 가입된 이메일입니다.';

  @override
  String get setUpProfile => '프로필 설정';

  @override
  String get editProfile => '프로필 수정';

  @override
  String get profileSubtitle => '맞춤 학습을 위해 사용됩니다.';

  @override
  String get displayName => '표시 이름';

  @override
  String get displayNameRequired => '표시 이름을 입력해 주세요.';

  @override
  String get startLearning => '학습 시작';

  @override
  String get settings => '설정';

  @override
  String get account => '계정';

  @override
  String get signOut => '로그아웃';

  @override
  String get signOutConfirmTitle => '로그아웃할까요?';

  @override
  String get signOutConfirmMessage => '정말 로그아웃하시겠어요?';

  @override
  String get about => '정보';

  @override
  String get version => '버전';

  @override
  String get nativeShort => '모국어';

  @override
  String get learningShort => '학습';

  @override
  String greetingName(String name) {
    return '$name님, 안녕하세요';
  }

  @override
  String dueNowLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '개 단어가 복습을 기다려요',
    );
    return '$_temp0';
  }

  @override
  String get memoryHealth => '기억 상태';

  @override
  String get addFirstWord => '첫 단어를 추가해 보세요.';

  @override
  String get addWordHelper => '뜻, 예문, 흔한 실수는 AI가 정리해 드려요.';

  @override
  String get answerIncorrect => '아쉬워요';

  @override
  String get verdictPass => '잘 기억했어요';

  @override
  String get verdictFail => '조금 더 연습해요';
}
