import 'package:flutter/material.dart';

class AppLocalizations {
  static const Map<String, Map<String, String>> translations = {
    // Auth Screen
    'password': {
      'en': 'Password',
      'ru': 'Пароль',
      'kk': 'Құпиясөз',
    },
    'login_tab': {
      'en': 'LOGIN',
      'ru': 'ВХОД',
      'kk': 'КІРУ',
    },
    'login': {
      'en': 'LOGIN',
      'ru': 'ВОЙТИ',
      'kk': 'КІРУ',
    },
    'register_tab': {
      'en': 'REGISTER',
      'ru': 'РЕГИСТРАЦИЯ',
      'kk': 'ТІРКЕЛУ',
    },
    'register': {
      'en': 'REGISTER',
      'ru': 'ЗАРЕГИСТРИРОВАТЬСЯ',
      'kk': 'ТІРКЕЛУ',
    },
    'fill_all_fields': {
      'en': 'Fill out all fields',
      'ru': 'Заполните все поля',
      'kk': 'Барлық өрістерді толтырыңыз',
    },
    'wrong_email_pass': {
      'en': 'Invalid email or password',
      'ru': 'Неверный email или пароль',
      'kk': 'Электрондық пошта немесе құпиясөз қате',
    },
    'reg_error': {
      'en': 'Registration error',
      'ru': 'Ошибка регистрации',
      'kk': 'Тіркелу қатесі',
    },
    'learn_easy': {
      'en': 'Learn languages easily',
      'ru': 'Учи языки легко',
      'kk': 'Тілдерді оңай үйрен',
    },
    'your_name': {
      'en': 'Your name',
      'ru': 'Ваше имя',
      'kk': 'Сіздің атыңыз',
    },

    // Layout
    'home': {
      'en': 'HOME',
      'ru': 'ДОМОЙ',
      'kk': 'ҮЙГЕ',
    },

    // Profile Screen
    'settings': {
      'en': 'SETTINGS',
      'ru': 'НАСТРОЙКИ',
      'kk': 'БАПТАУЛАР',
    },
    'path_to_phase': {
      'en': 'Path to Phase',
      'ru': 'Путь к Фазе',
      'kk': 'Кезеңге жол',
    },
    'interface_lang': {
      'en': 'INTERFACE LANGUAGE',
      'ru': 'ЯЗЫК ИНТЕРФЕЙСА',
      'kk': 'ИНТЕРФЕЙС ТІЛІ',
    },
    'statistics': {
      'en': 'STATISTICS',
      'ru': 'СТАТИСТИКА',
      'kk': 'СТАТИСТИКА',
    },
    'current_streak': {
      'en': 'Current Streak:',
      'ru': 'Текущий Стрик:',
      'kk': 'Ағымдағы стрик:',
    },
    'days': {
      'en': 'Days',
      'ru': 'Дней',
      'kk': 'Күн',
    },
    'days_short': {
      'en': 'd.',
      'ru': 'дн.',
      'kk': 'к.',
    },
    'vocab_progress': {
      'en': 'Vocabulary Progress:',
      'ru': 'Прогресс Словаря:',
      'kk': 'Сөздік прогресі:',
    },
    'stages_completed': {
      'en': 'Stages Completed:',
      'ru': 'Завершено Ступеней:',
      'kk': 'Аяқталған кезеңдер:',
    },
    'logout': {
      'en': 'LOGOUT',
      'ru': 'ВЫЙТИ',
      'kk': 'ШЫҒУ',
    },
    'user_default': {
      'en': 'User',
      'ru': 'Пользователь',
      'kk': 'Пайдаланушы',
    },
    'lesson': {
      'en': 'Lesson',
      'ru': 'Урок',
      'kk': 'Сабақ',
    },

    // Categories
    'vocabulary_cat': {
      'en': 'VOCABULARY',
      'ru': 'СЛОВАРЬ',
      'kk': 'СӨЗДІК',
    },
    'grammar_cat': {
      'en': 'GRAMMAR',
      'ru': 'ГРАММАТИКА',
      'kk': 'ГРАММАТИКА',
    },
    'listening_cat': {
      'en': 'LISTENING',
      'ru': 'НА СЛУХ',
      'kk': 'ТЫҢДАЛЫМ',
    },
    'speaking_cat': {
      'en': 'SPEAKING',
      'ru': 'ГОВОРЕНИЕ',
      'kk': 'АЙТЫЛЫМ',
    },

    // Home / Category
    'no_connection': {
      'en': 'No connection to server.\nStart the backend and press retry.',
      'ru': 'Нет подключения к серверу.\nЗапустите бэкенд и нажмите повторить.',
      'kk': 'Сервермен байланыс жоқ.\nБэкендті іске қосып, қайталауды басыңыз.',
    },
    'error_occured': {
      'en': 'An error occurred:',
      'ru': 'Произошла ошибка:',
      'kk': 'Қате орын алды:',
    },
    'retry': {
      'en': 'Retry',
      'ru': 'Повторить',
      'kk': 'Қайталау',
    },
    'sections_phase': {
      'en': 'Sections: Phase ',
      'ru': 'Разделы: Фаза ',
      'kk': 'Бөлімдер: Фаза ',
    },

    // Trainers
    'lesson_completed': {
      'en': 'Lesson completed! +25 XP',
      'ru': 'Урок завершён! +25 XP',
      'kk': 'Сабақ аяқталды! +25 XP',
    },
    'no_data': {
      'en': 'No data available',
      'ru': 'Нет данных',
      'kk': 'Мәлімет жоқ',
    },
    'no_data_lesson': {
      'en': 'No data for this lesson',
      'ru': 'Нет данных для этого урока',
      'kk': 'Бұл сабақта мәлімет жоқ',
    },
    'next': {
      'en': 'NEXT',
      'ru': 'ДАЛЕЕ',
      'kk': 'КЕЛЕСІ',
    },
    'finish': {
      'en': 'FINISH',
      'ru': 'ЗАВЕРШИТЬ',
      'kk': 'АЯҚТАУ',
    },
    'finish_lesson': {
      'en': 'FINISH LESSON',
      'ru': 'ЗАВЕРШИТЬ УРОК',
      'kk': 'САБАҚТЫ АЯҚТАУ',
    },
    'check': {
      'en': 'CHECK',
      'ru': 'ПРОВЕРИТЬ',
      'kk': 'ТЕКСЕРУ',
    },
    'correct_status': {
      'en': 'Correct!',
      'ru': 'Правильно!',
      'kk': 'Дұрыс!',
    },
    'incorrect_status': {
      'en': 'Incorrect',
      'ru': 'Неправильно',
      'kk': 'Қате',
    },
    'try_again_status': {
      'en': 'Try again',
      'ru': 'Попробуйте ещё',
      'kk': 'Қайта көріңіз',
    },
    'great_status': {
      'en': 'Great!',
      'ru': 'Отлично!',
      'kk': 'Керемет!',
    },
    'correct_answer_is': {
      'en': 'Correct answer:',
      'ru': 'Правильный ответ:',
      'kk': 'Дұрыс жауап:',
    },

    // Vocabulary Trainer
    'hide_translation': {
      'en': 'Tap to hide',
      'ru': 'Нажмите чтобы скрыть',
      'kk': 'Жасыру үшін басыңыз',
    },
    'show_translation': {
      'en': 'Tap to see translation',
      'ru': 'Нажмите чтобы увидеть перевод',
      'kk': 'Аударманы көру үшін басыңыз',
    },
    'pronounce': {
      'en': 'PRONOUNCE',
      'ru': 'ПРОИЗНЕСТИ',
      'kk': 'АЙТУ',
    },

    // Listening Trainer
    'listen_and_type': {
      'en': 'Listen and type:',
      'ru': 'Прослушайте и напишите:',
      'kk': 'Тыңдап, жазыңыз:',
    },
    'type_what_you_hear': {
      'en': 'Type what you hear...',
      'ru': 'Введите услышанное...',
      'kk': 'Естігеніңізді жазыңыз...',
    },

    // Grammar Trainer
    'translate': {
      'en': 'Translate:',
      'ru': 'Переведите:',
      'kk': 'Аударыңыз:',
    },
    'write_in_english': {
      'en': 'Write in English:',
      'ru': 'Напишите по-английски:',
      'kk': 'Ағылшынша жазыңыз:',
    },

    // Speaking Trainer
    'read_aloud': {
      'en': 'Read aloud:',
      'ru': 'Прочитайте вслух:',
      'kk': 'Дауыстап оқыңыз:',
    },
    'listening_mic': {
      'en': 'Listening... (Tap to stop)',
      'ru': 'Слушаю... (Нажмите чтобы остановить)',
      'kk': 'Тыңдалуда... (Тоқтату үшін басыңыз)',
    },
    'tap_to_speak': {
      'en': 'Tap to speak',
      'ru': 'Нажмите чтобы произнести',
      'kk': 'Сөйлеу үшін басыңыз',
    },
    'mic_unavailable': {
      'en': 'Microphone unavailable',
      'ru': 'Микрофон недоступен',
      'kk': 'Микрофон қолжетімсіз',
    },
    'accuracy': {
      'en': 'Accuracy:',
      'ru': 'Точность:',
      'kk': 'Дәлдік:',
    },
    'heard': {
      'en': 'Heard:',
      'ru': 'Услышано:',
      'kk': 'Естілді:',
    },

    // Placement Screen
    'determining_level': {
      'en': 'Determining your level...',
      'ru': 'Определяем ваш уровень...',
      'kk': 'Деңгейіңізді анықтаудамыз...',
    },
    'go_to_lessons': {
      'en': 'Go to lessons',
      'ru': 'Перейти к урокам',
      'kk': 'Сабақтарға өту',
    },
    'i_dont_know': {
      'en': 'I DON\'T KNOW',
      'ru': 'Я НЕ ЗНАЮ',
      'kk': 'БІЛМЕЙМІН',
    },

    // Exam Screen
    'final_exam': {
      'en': 'Final Exam',
      'ru': 'Финальный Экзамен',
      'kk': 'Қорытынды Емтихан',
    },
    'congratulations': {
      'en': 'CONGRATULATIONS!',
      'ru': 'ПОЗДРАВЛЯЕМ!',
      'kk': 'ҚҰТТЫҚТАЙМЫЗ!',
    },
    'try_again_cap': {
      'en': 'TRY AGAIN',
      'ru': 'ПОПРОБУЙТЕ ЕЩЁ',
      'kk': 'ҚАЙТАЛАҢЫЗ',
    },
    'your_score': {
      'en': 'Your score:',
      'ru': 'Ваш результат:',
      'kk': 'Сіздің нәтижеңіз:',
    },
    'correct_answers_count': {
      'en': 'correct answers', // Usage: N/M correct answers
      'ru': 'правильных ответов',
      'kk': 'дұрыс жауап',
    },
    'you_reached_phase': {
      'en': 'You advanced to Phase',
      'ru': 'Вы перешли на Фазу',
      'kk': 'Сіз жаңа кезеңге өттіңіз: Фаза',
    },
    'interactive_games': {
      'en': 'Interactive Games',
      'ru': 'Интерактивные Игры',
      'kk': 'Интерактивті ойындар',
    },
    'word_match': {
      'en': 'Word Match',
      'ru': 'Собери пары',
      'kk': 'Сөздерді сәйкестендір',
    },
    'word_sprint': {
      'en': 'Word Sprint',
      'ru': 'Спринт',
      'kk': 'Спринт',
    },
    'true_label': {
      'en': 'True',
      'ru': 'Правда',
      'kk': 'Шындық',
    },
    'false_label': {
      'en': 'False',
      'ru': 'Ложь',
      'kk': 'Жалған',
    },
    'score': {
      'en': 'Score',
      'ru': 'Счёт',
      'kk': 'Ұпай',
    },
    'combo': {
      'en': 'Combo',
      'ru': 'Комбо',
      'kk': 'Комбо',
    },
    'game_over': {
      'en': 'Game Over!',
      'ru': 'Игра окончена!',
      'kk': 'Ойын аяқталды!',
    },
    'play_again': {
      'en': 'Play Again',
      'ru': 'Играть снова',
      'kk': 'Қайта ойнау',
    },
    'new_record': {
      'en': 'New Record!',
      'ru': 'Новый Рекорд!',
      'kk': 'Жаңа Рекорд!',
    },
    'best_score': {
      'en': 'Best',
      'ru': 'Лучший',
      'kk': 'Үздік',
    },
    'question': {
      'en': 'Question',
      'ru': 'Вопрос',
      'kk': 'Сұрақ',
    },
    'of': {
      'en': 'of',
      'ru': 'из',
      'kk': '-',
    },
    'your_translation': {
      'en': 'Your translation...',
      'ru': 'Ваш перевод...',
      'kk': 'Сіздің аудармаңыз...',
    },
    'answer': {
      'en': 'ANSWER',
      'ru': 'ОТВЕТИТЬ',
      'kk': 'ЖАУАП БЕРУ',
    },
    'finish_exam': {
      'en': 'FINISH EXAM',
      'ru': 'ЗАВЕРШИТЬ ЭКЗАМЕН',
      'kk': 'ЕМТИХАНДЫ АЯҚТАУ',
    },
  };

  static String tr(String key, String lang) {
    if (translations.containsKey(key)) {
      final text = translations[key]![lang];
      return text ?? translations[key]!['ru'] ?? key; // default to ru or key
    }
    return key;
  }
}
