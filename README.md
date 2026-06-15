# Черновик (Draft) v0.3.0

**Жанр:** Визуальная новелла-песочница с элементами хоррора
**Движок:** Godot 4.6
**Платформы:** Linux, Windows, macOS

## Концепция

Ты находишь старый ноутбук. На нём открыт документ «Черновик мира».
Удали строчку — она исчезнет из реальности. Добавь новую — появится.
Мир сопротивляется изменениям.

## Архитектура

### Поток данных (v0.3.0 — EventBus-only)

```
DocumentEditor  ──► WorldState ──► EventBus ──► Consequences
     ▲                  ▲              │              │
     │                  │              ├──► GameProgress
     └── UI refresh ◄───┘              ├──► CharacterManager
                                       └──► MetaMemory
```

**Правило:** WorldState НЕ вызывает Consequences напрямую. Всё через EventBus.

### Soft-delete модель

Удалённые строки НЕ стираются из памяти — они помечаются `active=false, hidden=true`.
Это позволяет:
- ErrorPerson'ам помнить удалённые версии мира
- MetaMemory отслеживать историю правок
- Потенциально "восстанавливать" удалённые строки

### Соглашение об именах событий

`verb_object` — единый стиль: `erased_lera`, `removed_crime`, `destroyed_school`.
Никаких `lera_exists_removed`.

## Структура проекта

```
chernovik/
├── project.godot
├── scenes/
│   ├── main.tscn
│   ├── rooms/           (bedroom, school, city_square, abandoned_apartment, street)
│   ├── characters/      (error_person.tscn)
│   ├── ui/              (document_editor, dialogue, ending_screen, main_menu)
│   └── world/           (void.tscn)
├── scripts/
│   ├── autoload/        (WorldState, Consequences, MetaMemory, GameProgress,
│   │                     AudioManager, EventBus, SaveManager)
│   ├── core/            (SceneManager, ExplorationScene, CharacterManager)
│   ├── ui/              (DocumentEditor, DialogueOverlay, EndingScreen, MainMenu)
│   └── characters/      (ErrorPerson)
├── assets/              (sprites, music, sounds, fonts)
└── resources/           (dialogues, consequences, world_entries)
```

## Что готово (v0.3.0)

- [x] Ядро: WorldState (soft-delete), Consequences (EventBus + recursion guard)
- [x] UI редактора документа с подключёнными сигналами удаления
- [x] Мета-память с унифицированным именованием событий
- [x] Save/Load система (SaveManager)
- [x] Проверка уникальности ключей при добавлении строк
- [x] Guard от рекурсивного каскада последствий
- [x] Система персонажей и «Ошибок»
- [x] Сцены локаций
- [x] Экран концовок
- [x] Главное меню
- [x] Игровая оболочка `main.tscn` с HUD, переходами между локациями и документом
- [x] Сюжетные диалоги по локациям и ключевым правкам
- [x] Первые «Ошибки» как NPC в изменённых версиях мира
- [x] Журнал реальности: текущая цель и видимые последствия
- [x] Вертикальный срез: правки → последствия → Нина → Ошибки → раскрытие правды → финал
- [x] Редактирование существующих строк документа
- [x] Восстановление текущей локации из сохранения
- [x] Дополнительные ветки: болезни, утопия, подчинение Максиму
- [x] Концовки `dictator` и `utopia_collapse` через игровые правки

## Что дальше

- [ ] Графика: спрайты, фоны, портреты
- [ ] Музыка и звуки
- [ ] Диалоги: вынести сценарий из кода в JSON/ресурсы
- [ ] Больше consequence-правил для болезней, денег, истории города и отношений
- [ ] Улучшить AI/патрулирование «Ошибок»
- [ ] Полноценные портреты персонажей и анимации исчезновения
- [ ] Баланс порогов прогресса и отдельные сценарные дни
- [ ] Экспортные настройки под Windows/Linux/macOS

## Запуск

```bash
cd ~/chernovik
godot --editor
# или:
godot ~/chernovik/project.godot
```
