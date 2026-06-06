# Предложение: Prediction Algorithm v2 за Мондиал 2026

Дата: 2026-06-06

## 1. Защо текущият алгоритъм не е достатъчен

Текущият локален модел е полезен за първи prototype, но е твърде груб за реална прогноза. В момента той разчита основно на:

- FIFA ranking snapshot;
- генерирани локални recent matches;
- опростена форма;
- средни отбелязани и допуснати голове;
- статичен deterministic модел.

Това води до няколко проблема:

- няма реални последни резултати от API;
- няма xG/xGA или качество на положенията;
- няма реална сила на съперниците;
- няма player availability;
- няма пазарна калибрация;
- няма симулация на целия турнир;
- шансът за спечелване на купата е твърде опростен;
- не отчита достатъчно форматa с 48 отбора, 12 групи и 8 най-добри трети отбора.

## 2. Изводи от външни източници

Статията на WinDailySports е betting-oriented, но е полезна като сигнал за фактори, които реалният модел трябва да отчита:

- futures odds за фаворитите;
- group-winner odds;
- новия формат с 12 групи и Round of 32;
- стойността на третото място в групите;
- home/host фактор за САЩ, Канада и Мексико;
- възможна ротация на големите отбори при лесна група;
- важността на bracket path, а не само силата на отбора;
- market movement преди и по време на турнира.

Важно: приложението не трябва да се позиционира като betting продукт, освен ако това не е изрично решено юридически и продуктово. Тези данни могат да се използват за калибрация на вероятности, но UI copy трябва да остане "прогноза", "вероятност" и "анализ", не "заложи".

## 3. Цел на Algorithm v2

Algorithm v2 трябва да дава:

- вероятност за победа, равенство и загуба за всеки мач;
- очаквани голове за двата отбора;
- прогнозен резултат;
- confidence score;
- кратко обяснение на прогнозата;
- вероятност за излизане от групата;
- вероятност за достигане на Round of 32, Round of 16, Quarter-final, Semi-final, Final;
- вероятност за спечелване на купата;
- обновяване при нови резултати, контузии, състави, odds movement и live данни.

## 4. Предложена архитектура

Моделът да бъде разделен на 4 слоя:

1. Data layer
2. Feature layer
3. Match model
4. Tournament simulation

Flutter приложението не трябва да смята всичко директно. Препоръчително е:

- backend да тегли и нормализира данните;
- backend да пази snapshot-и;
- backend да генерира прогнозите;
- Flutter да визуализира готовите резултати;
- Flutter да има fallback local model само при development/offline режим.

## 5. Данни, които трябва да се добавят

### 5.1 Team strength

Показатели:

- FIFA ranking points;
- Elo rating;
- recent Elo change;
- strength of schedule;
- резултати срещу топ 10, топ 25, топ 50;
- performance на неутрален терен;
- performance на континентални и световни турнири;
- consistency score.

FIFA ranking е стабилен официален сигнал, но не е достатъчен. Elo е по-полезен за прогнози, защото може да отчита резултат, сила на съперник, домакинство и понякога голова разлика.

### 5.2 Form

Да се използва реална форма от последни мачове:

- последни 5 мача;
- последни 10 мача;
- последни 20 мача;
- weighted form, където по-новите мачове тежат повече;
- отделно official matches и friendlies;
- отделно home/away/neutral;
- резултат срещу очакван резултат според рейтинга на съперника.

Примерна тежест:

- последни 5 мача: 35%;
- мачове 6-10: 30%;
- мачове 11-20: 25%;
- дългосрочна стабилност: 10%.

### 5.3 Attack and defense

Минимални показатели:

- goals for per 90;
- goals against per 90;
- shots per 90;
- shots on target per 90;
- big chances;
- xG per 90;
- xGA per 90;
- set-piece xG;
- conversion rate;
- goalkeeper save rate;
- clean sheet rate;
- goals conceded after 75th minute.

Ако няма xG данни за всички национални мачове, моделът трябва да има fallback:

- xG available: използва xG/xGA;
- xG missing: използва adjusted goals + shots + opponent strength;
- no shot data: използва goals + Elo/FIFA + match type.

### 5.4 Squad quality

За всеки отбор:

- средна възраст;
- брой играчи от топ 5 лиги;
- брой играчи от Champions League/Europa League клубове;
- top player index;
- depth index по позиции;
- goalkeeper quality;
- defensive line experience;
- midfield creativity;
- attacking star power;
- captain/leadership score;
- minutes played през сезона;
- injury/suspension status.

Първа версия на squad score:

```text
squad_score =
  0.25 * top_5_leagues_share
  + 0.20 * player_caps_experience
  + 0.20 * player_goals_contribution
  + 0.15 * position_depth
  + 0.10 * goalkeeper_score
  + 0.10 * age_balance
```

### 5.5 Player availability

Да се отчита:

- контузии;
- наказания;
- expected lineup;
- minutes restriction;
- late replacements;
- rotation risk;
- key player absence.

Особено важно:

- голмайстор;
- основен вратар;
- водещ централен защитник;
- основен defensive midfielder;
- playmaker.

### 5.6 Tactical/context data

Показатели:

- coach tenure;
- style stability;
- average possession;
- pressing intensity, ако има данни;
- transition/counterattack strength;
- set-piece dependence;
- defensive block height;
- tournament experience;
- knockout experience.

### 5.7 Match context

За всеки мач:

- host advantage;
- venue;
- travel distance;
- local timezone adjustment;
- rest days;
- kickoff time;
- weather;
- altitude/heat/humidity;
- whether team needs a win;
- rotation probability;
- group standing before match;
- referee tendencies, ако има данни.

За домакините САЩ, Канада и Мексико да има host adjustment, но не еднакъв за всички мачове. Например:

- Mexico в Mexico City: висок host/venue adjustment;
- Canada в Toronto/Vancouver: среден host adjustment;
- USA в USA venues: среден host adjustment;
- neutral teams: travel/fatigue adjustment според локацията.

### 5.8 Market data

Може да се използва като калибрационен слой:

- win/draw/loss odds;
- group winner odds;
- outright winner odds;
- line movement;
- implied probability after removing bookmaker margin;
- disagreement между market и internal model.

Важно: market data не трябва да замества модела напълно. То трябва да го калибрира.

Пример:

```text
final_probability =
  alpha * internal_model_probability
  + (1 - alpha) * market_implied_probability
```

Където:

- alpha = 0.75 при добри internal данни;
- alpha = 0.55 при липсващо xG/player availability;
- alpha = 0.35 при много непълни данни.

## 6. Match Model v2

### 6.1 Базов рейтинг

За всеки отбор се смята `team_power`:

```text
team_power =
  0.22 * elo_strength
  + 0.13 * fifa_ranking_strength
  + 0.16 * recent_form
  + 0.16 * attack_strength
  + 0.16 * defense_strength
  + 0.09 * squad_quality
  + 0.04 * coach_tactical_stability
  + 0.04 * tournament_experience
```

Тези тегла са начални. След backtest трябва да се оптимизират.

### 6.2 Expected goals

Да се използва Poisson/Dixon-Coles-style подход:

```text
lambda_home =
  exp(
    base_goal_rate
    + attack_home
    - defense_away
    + context_home
    + squad_home
    - availability_penalty_home
  )

lambda_away =
  exp(
    base_goal_rate
    + attack_away
    - defense_home
    + context_away
    + squad_away
    - availability_penalty_away
  )
```

След това:

- симулираме scoreline probabilities от 0:0 до 8:8;
- добавяме корекция за нискорезултатни равенства;
- сумираме вероятностите за home win, draw, away win;
- избираме най-вероятния резултат или expected score.

### 6.3 Draw probability

Текущият модел третира равенството твърде грубо.

Draw probability трябва да зависи от:

- близост на rating-а;
- ниски lambda стойности;
- defensive strength;
- tournament context;
- дали равенство устройва и двата отбора;
- трети мач в групата;
- knockout 90-minute draw probability.

### 6.4 Confidence score

Confidence не трябва да е просто разлика между първа и втора вероятност.

Предложение:

```text
confidence =
  0.35 * probability_gap
  + 0.20 * data_quality
  + 0.15 * model_market_agreement
  + 0.15 * injury_data_completeness
  + 0.15 * lineup_confidence
```

UI да показва confidence като:

- ниска;
- средна;
- висока;
- не като гаранция.

## 7. Tournament Simulation

За шанс за купата не трябва да се използва само рейтинг.

Трябва да се симулира целият турнир:

1. Симулиране на всички групови мачове.
2. Класиране по FIFA tie-break rules.
3. Избор на 8 най-добри трети отбора.
4. Генериране на Round of 32 bracket.
5. Симулиране на knockout мачове.
6. Повторение 50 000 - 100 000 пъти.
7. Изчисляване на:
   - group winner probability;
   - qualification probability;
   - Round of 16 probability;
   - Quarter-final probability;
   - Semi-final probability;
   - Final probability;
   - trophy probability.

Примерен output:

```json
{
  "teamId": "esp",
  "groupWinner": 0.71,
  "qualifyR32": 0.94,
  "reachR16": 0.78,
  "reachQF": 0.58,
  "reachSF": 0.36,
  "reachFinal": 0.22,
  "winCup": 0.13
}
```

## 8. Данни и API

### 8.1 Минимален backend data contract

```text
TeamRatingSnapshot
- teamId
- fifaRanking
- fifaPoints
- eloRating
- eloDate
- formScore5
- formScore10
- formScore20
- attackScore
- defenseScore
- squadScore
- injuryImpact
- dataQuality
- updatedAt

MatchPrediction
- matchId
- modelVersion
- homeWinProbability
- drawProbability
- awayWinProbability
- expectedHomeGoals
- expectedAwayGoals
- mostLikelyScore
- confidence
- explanationFactors
- generatedAt

TournamentSimulation
- modelVersion
- simulationCount
- teamStageProbabilities
- generatedAt
```

### 8.2 Препоръчани източници

Primary/official:

- FIFA fixtures, groups, squads, rankings;
- FIFA ranking procedure;
- official squad updates.

Operational API:

- Sportmonks: fixtures, squads, standings, xG, odds, predictions, live data;
- API-Football: fixtures, standings, teams, players, odds/predictions depending on coverage;
- Statorium/WorldCup API като backup/secondary options;
- football-data.org за по-прости fixtures/results, ако бюджетът е ограничен.

Open/reference:

- OpenFootball за static fixture seed;
- StatsBomb open data за research/backtest методология, не за live World Cup feed.

Market data:

- само ако юридически е окей;
- да се използва за calibration, не като betting UI.

## 9. Feature Weights - първа реална версия

Предложение за първи production-ready модел:

```text
Base team strength:        35%
Recent form:               15%
Attack/defense metrics:    20%
Squad quality/availability:15%
Match context:             10%
Market calibration:         5%
```

Ако има reliable odds feed:

```text
Base team strength:        30%
Recent form:               12%
Attack/defense metrics:    18%
Squad quality/availability:15%
Match context:             10%
Market calibration:        15%
```

Ако няма xG:

```text
Elo/FIFA/form трябва да получат по-висока тежест,
а attack/defense да се смята от adjusted goals и shots.
```

## 10. Обяснимост в UI

Всяка прогноза трябва да показва 3-5 основни фактора:

Пример:

```text
Brazil има по-висок attack score и по-добър Elo rating.
Morocco има силна защита и добър tournament experience score.
Моделът отчита неутрален терен и сходна почивка между мачовете.
Затова прогнозата е Brazil 48%, Draw 27%, Morocco 25%.
```

Да се избягва:

- "сигурна прогноза";
- "заложи";
- "гарантиран резултат";
- aggressive betting copy.

## 11. Backtesting и оценка

Преди production трябва да се направи backtest.

Dataset:

- World Cup 2014, 2018, 2022;
- Euro 2016, 2020, 2024;
- Copa America;
- AFCON;
- Asian Cup;
- CONCACAF Gold Cup;
- квалификации и приятелски срещи с по-ниска тежест.

Метрики:

- log loss за W/D/L;
- Brier score;
- calibration curve;
- expected calibration error;
- MAE за expected goals;
- exact score accuracy само като secondary metric;
- ROI не трябва да е основна метрика, освен ако продуктът не стане betting app.

## 12. Update Cadence

Препоръка:

- static tournament data: 1-2 пъти дневно;
- squads/injuries: на 30-60 минути;
- odds/market calibration: на 5-15 минути, ако има feed;
- live match data: 10-30 секунди, според API лимитите;
- predictions: regenerate при нов резултат, injury update, lineup update, odds movement или промяна в standings.

## 13. Roadmap

### Phase 1: Algorithm v2 offline

- Добавяне на реални last 20 matches за всички отбори.
- Реален FIFA/Elo rating snapshot.
- Реални squad caps/goals/club/age features.
- Poisson scoreline model.
- Tournament simulation.
- Нови tests за probabilities и calibration sanity.

### Phase 2: Backend integration

- Избор на API provider.
- Нормализиране на fixtures, teams, squads, results, injuries.
- Snapshot таблици.
- Prediction job.
- Cache и fallback.

### Phase 3: Calibration

- Backtest.
- Оптимизация на теглата.
- Market implied probability comparison.
- Confidence tuning.

### Phase 4: UI upgrade

- Обяснение на прогнозата с фактори.
- Stage probabilities на team page.
- Раздел "Защо този процент?".
- Data freshness indicator.

## 14. Конкретна препоръка

Най-добрият следващ ход е:

1. Да оставим текущия local model като fallback.
2. Да създадем нов `PredictionEngineV2` в backend или отделен Dart service.
3. Да добавим реални rating snapshots и last 20 matches.
4. Да сменим мачовите прогнози от текущото score сравнение към Poisson model.
5. Да смятаме шанс за купата чрез Monte Carlo simulation, не чрез единичен team score.
6. Да добавим data quality score, за да знаем кога прогнозата е слаба.

## 15. Източници

- WinDailySports, FIFA World Cup 2026 Ultimate Betting Guide: https://windailysports.com/fifa-world-cup-2026-betting-guide/
- FIFA Men's World Ranking Procedure: https://inside.fifa.com/fifa-world-ranking/procedure-men
- Sportmonks Football API 3.0 endpoints: https://docs.sportmonks.com/v3/endpoints-and-entities/endpoints
- API-Football documentation: https://www.api-football.com/documentation-v3
- Interpretable football prediction with FIFA ratings and team formation: https://pmc.ncbi.nlm.nih.gov/articles/PMC10101499/
- Double Poisson model for football results: https://pmc.ncbi.nlm.nih.gov/articles/PMC9119507/
- Elo-based World Cup modelling reference: https://arxiv.org/abs/1806.01930
- World Cup 2026 squad reference: https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_squads
