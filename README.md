# Черновик (Draft) v0.1.0

**Жанр:** Визуальная новелла-песочница с элементами хоррора
**Движок:** Godot 4.6
**Платформы:** Linux, Windows, macOS

## Концепция

Ты находишь старый ноутбук. На нём открыт документ «Черновик мира».
В нём записано всё: люди, события, воспоминания, законы физики.
Удали строчку — она исчезнет из реальности.
Добавь новую — появится.

Проблема в том, что мир сопротивляется изменениям.

## Структура проекта

```
chernovik/
├── project.godot              # Конфигурация Godot
├── scenes/
│   ├── main.tscn              # Главная сцена (SceneManager + DialogueOverlay)
│   ├── rooms/                 # Игровые локации
│   │   ├── bedroom.tscn       # Комната Максима
│   │   ├── school.tscn        # Школа №17
│   │   ├── city_square.tscn   # Центральная площадь
│   │   ├── abandoned_apartment.tscn  # Заброшенная квартира
│   │   └── street.tscn        # Улица Мира
│   ├── characters/
│   │   └── error_person.tscn  # «Ошибка» — помнит прошлые версии мира
│   ├── ui/
│   │   ├── document_editor.tscn      # Главный UI — редактор документа
│   │   ├── document_entry_row.tscn   # Одна строка документа
│   │   ├── dialogue_choice_button.tscn
│   │   ├── main_menu.tscn
│   │   └── ending_screen.tscn
│   └── world/
│       └── void.tscn          # Пустота (финал)
├── scripts/
│   ├── autoload/              # Синглтоны (загружаются при старте)
│   │   ├── WorldState.gd      # Ядро — состояние мира
│   │   ├── Consequences.gd    # Система правил/последствий
│   │   ├── MetaMemory.gd      # Память между прохождениями
│   │   ├── GameProgress.gd    # Прогресс по сюжету
│   │   ├── AudioManager.gd    # Музыка и звуки
│   │   └── EventBus.gd        # Глобальная шина событий
│   ├── core/
│   │   ├── SceneManager.gd    # Переключение сцен
│   │   ├── ExplorationScene.gd # Базовая сцена исследования
│   │   └── CharacterManager.gd # Управление персонажами
│   ├── ui/
│   │   ├── DocumentEditor.gd  # Логика редактора документа
│   │   ├── DocumentEntryRow.gd # Логика строки документа
│   │   ├── DialogueOverlay.gd # Оверлей диалогов (VN-style)
│   │   ├── DialogueChoiceButton.gd
│   │   ├── MainMenu.gd
│   │   └── EndingScreen.gd
│   └── characters/
│       └── ErrorPerson.gd     # Логика «Ошибок»
├── assets/
│   ├── sprites/               # Графика
│   ├── music/                 # Музыка
│   ├── sounds/                # Звуковые эффекты
│   └── fonts/                 # Шрифты
└── resources/
    ├── dialogues/             # JSON-файлы диалогов
    ├── consequences/          # Таблицы правил последствий
    └── world_entries/         # Стартовые наборы строк мира
```

## Архитектура

### Ядро — WorldState
Все «строки документа» хранятся в синглтоне `WorldState`.
Когда игрок удаляет строку → `WorldState.remove_entry(key)` → Consequences вычисляет цепочку эффектов → другие системы реагируют через EventBus.

### Система последствий
Каждое действие запускает каскад:
- **Немедленные:** добавить/удалить другие строки сразу
- **Отложенные:** эффект происходит через N правок («экономика рухнула не сразу»)

### Мета-память
`MetaMemory` сохраняет информацию о всех прохождениях в `user://meta/runs.json`.
Персонажи могут ссылаться на события из прошлых прохождений.

### «Ошибки»
`ErrorPerson` получает снапшот мира из определённого момента истории правок.
Сравнивает его с текущим состоянием — и реагирует соответственно.

## Запуск

```bash
cd ~/chernovik
godot --editor
```

Или запустить игру сразу:
```bash
godot ~/chernovik/project.godot
```

## Что готово

- [x] Архитектура ядра (WorldState, Consequences, EventBus)
- [x] Система мета-памяти (MetaMemory)
- [x] Прогресс по сюжету (GameProgress)
- [x] Аудио-менеджер (AudioManager)
- [x] UI редактора документа (DocumentEditor + DocumentEntryRow)
- [x] Система диалогов (DialogueOverlay)
- [x] Управление персонажами (CharacterManager)
- [x] Система «Ошибок» (ErrorPerson)
- [x] Сцены локаций (bedroom, school, city_square, abandoned_apartment, street)
- [x] Экран концовок (EndingScreen)
- [x] Главное меню (MainMenu)

## Что дальше (MVP)

- [ ] Графика: спрайты персонажей, фоны, иконки
- [ ] Музыка и звуки: создание/поиск ассетов
- [ ] Диалоги: написание JSON-файлов для сцен
- [ ] Сохранение/загрузка
- [ ] Настройка аудио-шин в Godot
- [ ] Тестирование геймплейной петли
- [ ] Портирование на Ren'Py-подобный визуальный стиль (портреты, текстовое окно)


