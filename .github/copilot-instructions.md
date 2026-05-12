# Copilot Instructions for Climb Endurance

## Project Overview
Climb Endurance is a Flutter mobile app for tracking rock climbing workouts. Users record sessions with sets, routes, and analyze performance via charts. Uses SQLite (sqflite) for local storage, fl_chart for visualizations, and CSV for data import/export.

## Architecture
- **Modular Structure**: UI (pages/widgets), Data (models/database), Charts (visualizations)
- **Key Files**:
  - `lib/src/models.dart`: Data classes (RouteEntry, WorkoutSession, WorkoutSet)
  - `lib/src/database.dart`: SQLite operations, schema migrations
  - `lib/src/pages/`: RecordPage (workout tracking), DataPage (charts), RawDataPage (editing)
  - `lib/src/charts.dart`: TrendChart, FalloffChart with set-based progress over time
  - `lib/src/widgets/`: Dialogs, SessionSetTable for editable tables

## Data Structures
- **RouteEntry**: id, name, wall, notes, holdCount, createdAt
- **WorkoutSession**: id, startedAt, endedAt, targetRestSeconds, notes
- **WorkoutSet**: id, sessionId, routeId, setNumber, startedAt, endedAt, wallTimeSeconds, restAfterSeconds, targetRestSeconds, movesCompleted, notes
- **SetWithRoute**: Combines set with routeName and sessionStartedAt

## Database Schema (Version 2)
- **routes**: id (PK), name, wall, notes, hold_count, created_at
- **sessions**: id (PK), started_at, ended_at, target_rest_seconds, notes
- **sets**: id (PK), session_id (FK), route_id (FK), set_number, started_at, ended_at (nullable), wall_time_seconds, rest_after_seconds (nullable), target_rest_seconds, moves_completed, notes
- Foreign keys enforced; sets.ended_at nullable for ongoing sets

## Key Workflows
### Workout Recording
1. Start workout → Create session + first set (restAfterSeconds=0)
2. Climb (timer up) → Rest → Enter moves/wall time → Update set, start rest timer
3. Start next set → Create new set with restAfterSeconds from previous rest
4. End workout → Discard current rest, end session

### Data Visualization
- Trend charts: Multi-line (one per set number), x-axis days since min date, y-axis metrics
- Filters: Time range, route filter
- Falloff: Moves vs set number/rest time

## Conventions
- Timestamps stored as milliseconds since epoch (int)
- Durations in seconds (int)
- Format durations as "m:ss" (utils.dart)
- Database operations async, use transactions for multi-step
- Charts exclude zero/null values where appropriate
- State management: Stateful widgets with setState, refresh on data changes

## Dependencies
- flutter: UI framework
- sqflite: SQLite database
- fl_chart: Charts
- intl: Date formatting
- csv: Data import
- synchronized: Lock for DB operations

## Common Patterns
- Editable tables: Focus listeners for persistence (session_set_table.dart)
- Dialogs: Barrier dismissible=false for required input
- Charts: sessionDates for aligned x-axes across charts
- Database: Upsert for routes, insert/update for sets/sessions

## Future Roadmap
- Multiple workout types (bouldering, sport, trad)
- Heart rate/GPS integration
- Audio cues for rest timers
- Dynamic plot types
- Cloud sync

Always reference docs/architecture.md for detailed diagrams and examples.
Always update docs/architecture.md docs/todo.md and .github/copilot-instructions.md with any new features or architectural changes.