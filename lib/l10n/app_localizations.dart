import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'UnEbb'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errorNetwork;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI service isn\'t responding right now. Please try again in a moment.'**
  String get errorAiUnavailable;

  /// No description provided for @errorClockSync.
  ///
  /// In en, this message translates to:
  /// **'Your device clock is out of sync. Set date & time to automatic and try again.'**
  String get errorClockSync;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing saved data.'**
  String get offlineBanner;

  /// No description provided for @offlineActionRequired.
  ///
  /// In en, this message translates to:
  /// **'An internet connection is required.'**
  String get offlineActionRequired;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Showing saved data.'**
  String get refreshFailed;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navDecks.
  ///
  /// In en, this message translates to:
  /// **'Decks'**
  String get navDecks;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @dashboardGreeting.
  ///
  /// In en, this message translates to:
  /// **'Ready to learn?'**
  String get dashboardGreeting;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your vocabulary to strengthen your memory.'**
  String get dashboardSubtitle;

  /// No description provided for @startReview.
  ///
  /// In en, this message translates to:
  /// **'Start Review'**
  String get startReview;

  /// No description provided for @wordsDue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word due for review} other{{count} words due for review}}'**
  String wordsDue(int count);

  /// No description provided for @nothingDue.
  ///
  /// In en, this message translates to:
  /// **'Nothing due — review anyway to stay sharp!'**
  String get nothingDue;

  /// No description provided for @yourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your Progress'**
  String get yourProgress;

  /// No description provided for @statDecks.
  ///
  /// In en, this message translates to:
  /// **'Decks'**
  String get statDecks;

  /// No description provided for @statWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get statWords;

  /// No description provided for @statMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get statMastered;

  /// No description provided for @recentDecks.
  ///
  /// In en, this message translates to:
  /// **'Recent Decks'**
  String get recentDecks;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @noDecksYet.
  ///
  /// In en, this message translates to:
  /// **'No decks yet'**
  String get noDecksYet;

  /// No description provided for @createFirstDeck.
  ///
  /// In en, this message translates to:
  /// **'Create your first deck to start learning!'**
  String get createFirstDeck;

  /// No description provided for @createDeck.
  ///
  /// In en, this message translates to:
  /// **'Create Deck'**
  String get createDeck;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String wordCount(int count);

  /// No description provided for @reviewOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Start review'**
  String get reviewOptionsTitle;

  /// No description provided for @deckReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review deck'**
  String get deckReviewTitle;

  /// No description provided for @reviewWhichWords.
  ///
  /// In en, this message translates to:
  /// **'Which words do you want to review?'**
  String get reviewWhichWords;

  /// No description provided for @reviewDueOnly.
  ///
  /// In en, this message translates to:
  /// **'Due words only'**
  String get reviewDueOnly;

  /// No description provided for @reviewAllWords.
  ///
  /// In en, this message translates to:
  /// **'All words'**
  String get reviewAllWords;

  /// No description provided for @reviewAllWordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New and weakest words first'**
  String get reviewAllWordsSubtitle;

  /// No description provided for @reviewHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many words?'**
  String get reviewHowMany;

  /// No description provided for @quickSelect.
  ///
  /// In en, this message translates to:
  /// **'Quick select'**
  String get quickSelect;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @voiceMode.
  ///
  /// In en, this message translates to:
  /// **'Voice Mode'**
  String get voiceMode;

  /// No description provided for @voiceModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Voice mode enabled'**
  String get voiceModeEnabled;

  /// No description provided for @voiceModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Voice mode disabled'**
  String get voiceModeDisabled;

  /// No description provided for @speakingWord.
  ///
  /// In en, this message translates to:
  /// **'Speaking word...'**
  String get speakingWord;

  /// No description provided for @listeningForMeaning.
  ///
  /// In en, this message translates to:
  /// **'Listening... Explain the meaning'**
  String get listeningForMeaning;

  /// No description provided for @listeningForTranslation.
  ///
  /// In en, this message translates to:
  /// **'Listening... Translate the sentence'**
  String get listeningForTranslation;

  /// No description provided for @tapMicToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap mic to speak'**
  String get tapMicToSpeak;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @voiceModeInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize voice mode. Please check microphone permissions.'**
  String get voiceModeInitFailed;

  /// No description provided for @speakNow.
  ///
  /// In en, this message translates to:
  /// **'Speak now'**
  String get speakNow;

  /// No description provided for @tapToStopListening.
  ///
  /// In en, this message translates to:
  /// **'Tap to stop listening'**
  String get tapToStopListening;

  /// No description provided for @tapToAnswer.
  ///
  /// In en, this message translates to:
  /// **'Tap to answer'**
  String get tapToAnswer;

  /// No description provided for @doYouKnowThisWord.
  ///
  /// In en, this message translates to:
  /// **'Do you know this word?'**
  String get doYouKnowThisWord;

  /// No description provided for @sayYesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Say yes or no'**
  String get sayYesOrNo;

  /// No description provided for @listeningForYesNo.
  ///
  /// In en, this message translates to:
  /// **'Listening... Say yes or no'**
  String get listeningForYesNo;

  /// No description provided for @iKnowIt.
  ///
  /// In en, this message translates to:
  /// **'I know it'**
  String get iKnowIt;

  /// No description provided for @iDontKnowIt.
  ///
  /// In en, this message translates to:
  /// **'I don\'t know it'**
  String get iDontKnowIt;

  /// No description provided for @explainTheMeaning.
  ///
  /// In en, this message translates to:
  /// **'Please explain the meaning'**
  String get explainTheMeaning;

  /// No description provided for @whatIsTheMeaning.
  ///
  /// In en, this message translates to:
  /// **'What is the meaning?'**
  String get whatIsTheMeaning;

  /// No description provided for @enterMeaningHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the meaning (e.g., adjacent)'**
  String get enterMeaningHint;

  /// No description provided for @submitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get submitAnswer;

  /// No description provided for @checkingYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Checking your answer…'**
  String get checkingYourAnswer;

  /// No description provided for @correctMeaning.
  ///
  /// In en, this message translates to:
  /// **'Correct meaning'**
  String get correctMeaning;

  /// No description provided for @nextWord.
  ///
  /// In en, this message translates to:
  /// **'Next word'**
  String get nextWord;

  /// No description provided for @preparingTranslationExercise.
  ///
  /// In en, this message translates to:
  /// **'Preparing translation exercise…'**
  String get preparingTranslationExercise;

  /// No description provided for @translateInto.
  ///
  /// In en, this message translates to:
  /// **'Translate into {language}'**
  String translateInto(String language);

  /// No description provided for @hintUseWord.
  ///
  /// In en, this message translates to:
  /// **'Hint: use \"{word}\"'**
  String hintUseWord(String word);

  /// No description provided for @yourTranslationHint.
  ///
  /// In en, this message translates to:
  /// **'Your {language} translation…'**
  String yourTranslationHint(String language);

  /// No description provided for @submitTranslation.
  ///
  /// In en, this message translates to:
  /// **'Submit translation'**
  String get submitTranslation;

  /// No description provided for @evaluatingYourTranslation.
  ///
  /// In en, this message translates to:
  /// **'Evaluating your translation…'**
  String get evaluatingYourTranslation;

  /// No description provided for @generatingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Generating explanation…'**
  String get generatingExplanation;

  /// No description provided for @wordExplanation.
  ///
  /// In en, this message translates to:
  /// **'Word Explanation'**
  String get wordExplanation;

  /// No description provided for @definition.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get definition;

  /// No description provided for @explanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get explanation;

  /// No description provided for @examples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get examples;

  /// No description provided for @synonyms.
  ///
  /// In en, this message translates to:
  /// **'Synonyms'**
  String get synonyms;

  /// No description provided for @collocations.
  ///
  /// In en, this message translates to:
  /// **'Collocations'**
  String get collocations;

  /// No description provided for @commonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common Mistakes'**
  String get commonMistakes;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @tapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal'**
  String get tapToReveal;

  /// No description provided for @meaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get meaning;

  /// No description provided for @usage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @wordUsage.
  ///
  /// In en, this message translates to:
  /// **'Word usage'**
  String get wordUsage;

  /// No description provided for @naturalness.
  ///
  /// In en, this message translates to:
  /// **'Naturalness'**
  String get naturalness;

  /// No description provided for @grammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get grammar;

  /// No description provided for @patternsToWatch.
  ///
  /// In en, this message translates to:
  /// **'Patterns to watch'**
  String get patternsToWatch;

  /// No description provided for @focusArea.
  ///
  /// In en, this message translates to:
  /// **'Focus area: {point}'**
  String focusArea(String point);

  /// No description provided for @memoryStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get memoryStrong;

  /// No description provided for @memoryGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get memoryGood;

  /// No description provided for @memoryWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get memoryWeak;

  /// No description provided for @memoryCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get memoryCritical;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get allCaughtUp;

  /// No description provided for @noDueWords.
  ///
  /// In en, this message translates to:
  /// **'No words are due for review right now.\nCome back later or add new words.'**
  String get noDueWords;

  /// No description provided for @reviewAllInstead.
  ///
  /// In en, this message translates to:
  /// **'Review all words'**
  String get reviewAllInstead;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @sessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session complete!'**
  String get sessionComplete;

  /// No description provided for @correctOutOf.
  ///
  /// In en, this message translates to:
  /// **'{correct} out of {total} correct'**
  String correctOutOf(int correct, int total);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @skipWord.
  ///
  /// In en, this message translates to:
  /// **'Skip word'**
  String get skipWord;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @aiContentMissing.
  ///
  /// In en, this message translates to:
  /// **'The AI explanation for this word isn\'t available yet.'**
  String get aiContentMissing;

  /// No description provided for @resumeSession.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get resumeSession;

  /// No description provided for @resumeSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue Previous Session?'**
  String get resumeSessionTitle;

  /// No description provided for @resumeSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'You have an unfinished review session with {remaining} words remaining ({completed} already completed).'**
  String resumeSessionMessage(int remaining, int completed);

  /// No description provided for @continueSession.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueSession;

  /// No description provided for @startNewSession.
  ///
  /// In en, this message translates to:
  /// **'Start New'**
  String get startNewSession;

  /// No description provided for @myDecks.
  ///
  /// In en, this message translates to:
  /// **'My Decks'**
  String get myDecks;

  /// No description provided for @errorLoadingDecks.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your decks.'**
  String get errorLoadingDecks;

  /// No description provided for @noDecksDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first deck to start organizing your vocabulary.'**
  String get noDecksDescription;

  /// No description provided for @deleteDeckTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete deck?'**
  String get deleteDeckTitle;

  /// No description provided for @deleteDeckMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete \"{name}\" and all its words. This cannot be undone.'**
  String deleteDeckMessage(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Please try again.'**
  String get deleteFailed;

  /// No description provided for @deckNotFound.
  ///
  /// In en, this message translates to:
  /// **'Deck not found'**
  String get deckNotFound;

  /// No description provided for @noWordsYet.
  ///
  /// In en, this message translates to:
  /// **'No words yet'**
  String get noWordsYet;

  /// No description provided for @addFirstWordToDeck.
  ///
  /// In en, this message translates to:
  /// **'Add your first word to this deck.'**
  String get addFirstWordToDeck;

  /// No description provided for @addWord.
  ///
  /// In en, this message translates to:
  /// **'Add Word'**
  String get addWord;

  /// No description provided for @deckName.
  ///
  /// In en, this message translates to:
  /// **'Deck name'**
  String get deckName;

  /// No description provided for @deckNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., TOEIC Vocabulary'**
  String get deckNameHint;

  /// No description provided for @deckNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a deck name'**
  String get deckNameRequired;

  /// No description provided for @deckDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get deckDescription;

  /// No description provided for @deckDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What is this deck for?'**
  String get deckDescriptionHint;

  /// No description provided for @duplicateDeckName.
  ///
  /// In en, this message translates to:
  /// **'A deck named \"{name}\" already exists.'**
  String duplicateDeckName(String name);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @learningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Learning language'**
  String get learningLanguage;

  /// No description provided for @nativeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Native language'**
  String get nativeLanguage;

  /// No description provided for @allWords.
  ///
  /// In en, this message translates to:
  /// **'All Words'**
  String get allWords;

  /// No description provided for @noWordsHint.
  ///
  /// In en, this message translates to:
  /// **'No words yet.\nAdd your first word to get started.'**
  String get noWordsHint;

  /// No description provided for @errorLoadingWords.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your words.'**
  String get errorLoadingWords;

  /// No description provided for @wordOrPhrase.
  ///
  /// In en, this message translates to:
  /// **'Word or phrase'**
  String get wordOrPhrase;

  /// No description provided for @wordHintExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. ephemeral'**
  String get wordHintExample;

  /// No description provided for @wordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a word'**
  String get wordRequired;

  /// No description provided for @editWord.
  ///
  /// In en, this message translates to:
  /// **'Edit Word'**
  String get editWord;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @deleteWordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete word?'**
  String get deleteWordTitle;

  /// No description provided for @deleteWordMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{word}\" from your vocabulary? This cannot be undone.'**
  String deleteWordMessage(String word);

  /// No description provided for @wordNotFound.
  ///
  /// In en, this message translates to:
  /// **'Word not found.'**
  String get wordNotFound;

  /// No description provided for @wordDetail.
  ///
  /// In en, this message translates to:
  /// **'Word Detail'**
  String get wordDetail;

  /// No description provided for @aiGenerating.
  ///
  /// In en, this message translates to:
  /// **'AI explanation is being generated…'**
  String get aiGenerating;

  /// No description provided for @aiFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate the AI explanation.'**
  String get aiFailed;

  /// No description provided for @aiMissing.
  ///
  /// In en, this message translates to:
  /// **'This word doesn\'t have an AI explanation yet.'**
  String get aiMissing;

  /// No description provided for @generateExplanation.
  ///
  /// In en, this message translates to:
  /// **'Generate explanation'**
  String get generateExplanation;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @wordAddedTitle.
  ///
  /// In en, this message translates to:
  /// **'Word Added'**
  String get wordAddedTitle;

  /// No description provided for @wordAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'\"{word}\" has been added to your vocabulary!'**
  String wordAddedSuccess(String word);

  /// No description provided for @practiceNow.
  ///
  /// In en, this message translates to:
  /// **'Practice Now'**
  String get practiceNow;

  /// No description provided for @duplicateWordError.
  ///
  /// In en, this message translates to:
  /// **'The word \"{word}\" already exists in this deck.'**
  String duplicateWordError(String word);

  /// No description provided for @duplicateWordInDeck.
  ///
  /// In en, this message translates to:
  /// **'\"{word}\" is already in the \"{deck}\" deck.'**
  String duplicateWordInDeck(String word, String deck);

  /// No description provided for @duplicateWordErrorGeneral.
  ///
  /// In en, this message translates to:
  /// **'This word already exists in your vocabulary.'**
  String get duplicateWordErrorGeneral;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Adaptive vocabulary learning'**
  String get tagline;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @noAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccountSignUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @checkEmailToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check your email and confirm your account, then sign in.'**
  String get checkEmailToConfirm;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get invalidCredentials;

  /// No description provided for @emailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email address first.'**
  String get emailNotConfirmed;

  /// No description provided for @userAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get userAlreadyExists;

  /// No description provided for @setUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get setUpProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps UnEbb personalise your experience.'**
  String get profileSubtitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @displayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your display name.'**
  String get displayNameRequired;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get startLearning;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmMessage;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @nativeShort.
  ///
  /// In en, this message translates to:
  /// **'Native'**
  String get nativeShort;

  /// No description provided for @learningShort.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get learningShort;

  /// No description provided for @greetingName.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String greetingName(String name);

  /// Shown next to a large due-word count on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{word ready to review} other{words ready to review}}'**
  String dueNowLabel(int count);

  /// No description provided for @memoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Memory health'**
  String get memoryHealth;

  /// No description provided for @addFirstWord.
  ///
  /// In en, this message translates to:
  /// **'Add your first word to get started.'**
  String get addFirstWord;

  /// No description provided for @addWordHelper.
  ///
  /// In en, this message translates to:
  /// **'AI writes the definition, examples and common mistakes for you.'**
  String get addWordHelper;

  /// No description provided for @answerIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get answerIncorrect;

  /// No description provided for @verdictPass.
  ///
  /// In en, this message translates to:
  /// **'Nice recall'**
  String get verdictPass;

  /// No description provided for @verdictFail.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing'**
  String get verdictFail;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
