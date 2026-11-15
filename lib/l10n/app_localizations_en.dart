// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UnEbb';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get start => 'Start';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorAiUnavailable =>
      'The AI service isn\'t responding right now. Please try again in a moment.';

  @override
  String get errorClockSync =>
      'Your device clock is out of sync. Set date & time to automatic and try again.';

  @override
  String get errorRateLimited =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get offlineBanner => 'You\'re offline. Showing saved data.';

  @override
  String get offlineActionRequired => 'An internet connection is required.';

  @override
  String get refreshFailed => 'Couldn\'t refresh. Showing saved data.';

  @override
  String get navHome => 'Home';

  @override
  String get navDecks => 'Decks';

  @override
  String get navSettings => 'Settings';

  @override
  String get dashboardGreeting => 'Ready to learn?';

  @override
  String get dashboardSubtitle =>
      'Review your vocabulary to strengthen your memory.';

  @override
  String get startReview => 'Start Review';

  @override
  String wordsDue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words due for review',
      one: '1 word due for review',
    );
    return '$_temp0';
  }

  @override
  String get nothingDue => 'Nothing due — review anyway to stay sharp!';

  @override
  String get yourProgress => 'Your Progress';

  @override
  String get statDecks => 'Decks';

  @override
  String get statWords => 'Words';

  @override
  String get statMastered => 'Mastered';

  @override
  String get recentDecks => 'Recent Decks';

  @override
  String get seeAll => 'See all';

  @override
  String get noDecksYet => 'No decks yet';

  @override
  String get createFirstDeck => 'Create your first deck to start learning!';

  @override
  String get createDeck => 'Create Deck';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get reviewOptionsTitle => 'Start review';

  @override
  String get deckReviewTitle => 'Review deck';

  @override
  String get reviewWhichWords => 'Which words do you want to review?';

  @override
  String get reviewDueOnly => 'Due words only';

  @override
  String get reviewAllWords => 'All words';

  @override
  String get reviewAllWordsSubtitle => 'New and weakest words first';

  @override
  String get reviewHowMany => 'How many words?';

  @override
  String get quickSelect => 'Quick select';

  @override
  String get review => 'Review';

  @override
  String get voiceMode => 'Voice Mode';

  @override
  String get voiceModeEnabled => 'Voice mode enabled';

  @override
  String get voiceModeDisabled => 'Voice mode disabled';

  @override
  String get speakingWord => 'Speaking word...';

  @override
  String get listeningForMeaning => 'Listening... Explain the meaning';

  @override
  String get listeningForTranslation => 'Listening... Translate the sentence';

  @override
  String get tapMicToSpeak => 'Tap mic to speak';

  @override
  String get processing => 'Processing...';

  @override
  String get voiceModeInitFailed =>
      'Failed to initialize voice mode. Please check microphone permissions.';

  @override
  String get speakNow => 'Speak now';

  @override
  String get tapToStopListening => 'Tap to stop listening';

  @override
  String get tapToAnswer => 'Tap to answer';

  @override
  String get doYouKnowThisWord => 'Do you know this word?';

  @override
  String get sayYesOrNo => 'Say yes or no';

  @override
  String get listeningForYesNo => 'Listening... Say yes or no';

  @override
  String get iKnowIt => 'I know it';

  @override
  String get iDontKnowIt => 'I don\'t know it';

  @override
  String get explainTheMeaning => 'Please explain the meaning';

  @override
  String get whatIsTheMeaning => 'What is the meaning?';

  @override
  String get enterMeaningHint => 'Enter the meaning (e.g., adjacent)';

  @override
  String get submitAnswer => 'Submit answer';

  @override
  String get checkingYourAnswer => 'Checking your answer…';

  @override
  String get correctMeaning => 'Correct meaning';

  @override
  String get nextWord => 'Next word';

  @override
  String get preparingTranslationExercise => 'Preparing translation exercise…';

  @override
  String translateInto(String language) {
    return 'Translate into $language';
  }

  @override
  String hintUseWord(String word) {
    return 'Hint: use \"$word\"';
  }

  @override
  String yourTranslationHint(String language) {
    return 'Your $language translation…';
  }

  @override
  String get submitTranslation => 'Submit translation';

  @override
  String get evaluatingYourTranslation => 'Evaluating your translation…';

  @override
  String get generatingExplanation => 'Generating explanation…';

  @override
  String get wordExplanation => 'Word Explanation';

  @override
  String get definition => 'Definition';

  @override
  String get explanation => 'Explanation';

  @override
  String get examples => 'Examples';

  @override
  String get synonyms => 'Synonyms';

  @override
  String get collocations => 'Collocations';

  @override
  String get commonMistakes => 'Common Mistakes';

  @override
  String get gotIt => 'Got it';

  @override
  String get tapToReveal => 'Tap to reveal';

  @override
  String get meaning => 'Meaning';

  @override
  String get usage => 'Usage';

  @override
  String get translation => 'Translation';

  @override
  String get wordUsage => 'Word usage';

  @override
  String get naturalness => 'Naturalness';

  @override
  String get grammar => 'Grammar';

  @override
  String get patternsToWatch => 'Patterns to watch';

  @override
  String focusArea(String point) {
    return 'Focus area: $point';
  }

  @override
  String get memoryStrong => 'Strong';

  @override
  String get memoryGood => 'Good';

  @override
  String get memoryWeak => 'Weak';

  @override
  String get memoryCritical => 'Critical';

  @override
  String get allCaughtUp => 'All caught up!';

  @override
  String get noDueWords =>
      'No words are due for review right now.\nCome back later or add new words.';

  @override
  String get reviewAllInstead => 'Review all words';

  @override
  String get back => 'Back';

  @override
  String get sessionComplete => 'Session complete!';

  @override
  String correctOutOf(int correct, int total) {
    return '$correct out of $total correct';
  }

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get skipWord => 'Skip word';

  @override
  String get finish => 'Finish';

  @override
  String get aiContentMissing =>
      'The AI explanation for this word isn\'t available yet.';

  @override
  String get resumeSession => 'Resume Session';

  @override
  String get resumeSessionTitle => 'Continue Previous Session?';

  @override
  String resumeSessionMessage(int remaining, int completed) {
    return 'You have an unfinished review session with $remaining words remaining ($completed already completed).';
  }

  @override
  String get continueSession => 'Continue';

  @override
  String get startNewSession => 'Start New';

  @override
  String get myDecks => 'My Decks';

  @override
  String get errorLoadingDecks => 'Couldn\'t load your decks.';

  @override
  String get noDecksDescription =>
      'Create your first deck to start organizing your vocabulary.';

  @override
  String get deleteDeckTitle => 'Delete deck?';

  @override
  String deleteDeckMessage(String name) {
    return 'This will delete \"$name\" and all its words. This cannot be undone.';
  }

  @override
  String get deleteFailed => 'Couldn\'t delete. Please try again.';

  @override
  String get deckNotFound => 'Deck not found';

  @override
  String get noWordsYet => 'No words yet';

  @override
  String get addFirstWordToDeck => 'Add your first word to this deck.';

  @override
  String get addWord => 'Add Word';

  @override
  String get deckName => 'Deck name';

  @override
  String get deckNameHint => 'e.g., TOEIC Vocabulary';

  @override
  String get deckNameRequired => 'Please enter a deck name';

  @override
  String get deckDescription => 'Description (optional)';

  @override
  String get deckDescriptionHint => 'What is this deck for?';

  @override
  String duplicateDeckName(String name) {
    return 'A deck named \"$name\" already exists.';
  }

  @override
  String get language => 'Language';

  @override
  String get learningLanguage => 'Learning language';

  @override
  String get nativeLanguage => 'Native language';

  @override
  String get allWords => 'All Words';

  @override
  String get noWordsHint =>
      'No words yet.\nAdd your first word to get started.';

  @override
  String get errorLoadingWords => 'Couldn\'t load your words.';

  @override
  String get wordOrPhrase => 'Word or phrase';

  @override
  String get wordHintExample => 'e.g. ephemeral';

  @override
  String get wordRequired => 'Please enter a word';

  @override
  String get editWord => 'Edit Word';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get deleteWordTitle => 'Delete word?';

  @override
  String deleteWordMessage(String word) {
    return 'Remove \"$word\" from your vocabulary? This cannot be undone.';
  }

  @override
  String get wordNotFound => 'Word not found.';

  @override
  String get wordDetail => 'Word Detail';

  @override
  String get aiGenerating => 'AI explanation is being generated…';

  @override
  String get aiFailed => 'Couldn\'t generate the AI explanation.';

  @override
  String get aiMissing => 'This word doesn\'t have an AI explanation yet.';

  @override
  String get generateExplanation => 'Generate explanation';

  @override
  String get feedback => 'Feedback';

  @override
  String get wordAddedTitle => 'Word Added';

  @override
  String wordAddedSuccess(String word) {
    return '\"$word\" has been added to your vocabulary!';
  }

  @override
  String get practiceNow => 'Practice Now';

  @override
  String duplicateWordError(String word) {
    return 'The word \"$word\" already exists in this deck.';
  }

  @override
  String duplicateWordInDeck(String word, String deck) {
    return '\"$word\" is already in the \"$deck\" deck.';
  }

  @override
  String get duplicateWordErrorGeneral =>
      'This word already exists in your vocabulary.';

  @override
  String get tagline => 'Adaptive vocabulary learning';

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get noAccountSignUp => 'Don\'t have an account? Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get checkEmailToConfirm =>
      'Check your email and confirm your account, then sign in.';

  @override
  String get invalidCredentials => 'Incorrect email or password.';

  @override
  String get emailNotConfirmed => 'Please confirm your email address first.';

  @override
  String get userAlreadyExists => 'An account with this email already exists.';

  @override
  String get setUpProfile => 'Set up your profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get profileSubtitle => 'This helps UnEbb personalise your experience.';

  @override
  String get displayName => 'Display name';

  @override
  String get displayNameRequired => 'Please enter your display name.';

  @override
  String get startLearning => 'Start learning';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get nativeShort => 'Native';

  @override
  String get learningShort => 'Learning';

  @override
  String greetingName(String name) {
    return 'Hi, $name';
  }

  @override
  String dueNowLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'words ready to review',
      one: 'word ready to review',
    );
    return '$_temp0';
  }

  @override
  String get memoryHealth => 'Memory health';

  @override
  String get addFirstWord => 'Add your first word to get started.';

  @override
  String get addWordHelper =>
      'AI writes the definition, examples and common mistakes for you.';

  @override
  String get answerIncorrect => 'Not quite';

  @override
  String get verdictPass => 'Nice recall';

  @override
  String get verdictFail => 'Keep practicing';
}
