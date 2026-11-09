# Feature Specification: AI Import of Workouts and Programs from Photos and Documents

**Feature Branch**: `002-ai-workout-import`

**Created**: 2026-11-08

**Status**: Draft

**Input**: User description: "Let a user take a picture, upload a picture, or upload a document (like a PDF) that has a workout or program on it. AI determines the workout or program details and shows the result to the user. If the user accepts, create that workout or program for them."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import a single workout from a photo or file (Priority: P1)

A lifter has a workout written on paper, a whiteboard or a coach's handout. They photograph it or choose an existing file, wait while it is read, check the result, and accept it. The workout then exists in their account exactly as if they had built it by hand.

**Why this priority**: This is the smallest complete version of the feature and removes the most tedious part of using the app, which is typing in a workout someone else wrote.

**Independent Test**: Submit a clear photo of a one-day workout, review the preview, accept it, and confirm a private workout with the right exercises and sets opens in the normal workout editor.

**Acceptance Scenarios**:

1. **Given** a signed-in user with imports available, **When** they submit a clear photo of a one-day workout, **Then** the import is processed and a preview shows the detected title, exercises, sets, reps and loads.
2. **Given** a preview of a workout, **When** the user accepts it, **Then** one private workout is created and opened in the existing workout editor.
3. **Given** a preview of a workout, **When** the user discards it, **Then** no workout or exercise is created and the uploaded files are removed.
4. **Given** a file that contains reps as a range, a percentage range, or a target effort (RPE), **When** it is imported, **Then** those values appear in the preview and on the created workout as ranges and targets rather than single rounded values.
5. **Given** a set prescribed as a percentage of a different lift (e.g. "Front Squat at 75% of Clean & Jerk"), **When** it is imported, **Then** the preview shows the lift the percentage is based on and the created set uses it.

---

### User Story 2 - Import a multi-week program (Priority: P1)

A lifter has a printed or PDF training program covering several weeks. They submit one PDF or several photos of its pages as one import. The app recognises it as a program, preserves its weeks and days, and creates a program the lifter can start whenever they choose.

**Why this priority**: Programs are where manual entry is most painful, often dozens of sessions, so this is the case that makes the feature worth having.

**Independent Test**: Submit a PDF of a multi-week program within the size limits, accept the preview, and confirm a private program appears with the right weeks, days, rest days and sets, and that it has not been started.

**Acceptance Scenarios**:

1. **Given** a PDF of a multi-week program, **When** it is imported, **Then** the preview identifies it as a program and shows its weeks, days, rest days, exercises and sets.
2. **Given** several photos of the pages of one program, **When** they are submitted as one import, **Then** the result combines them in page order into a single program.
3. **Given** a preview of a program, **When** the user accepts it, **Then** a private program is created and opened in the existing program editor, and no program run is started.
4. **Given** a file the app read as the wrong type, **When** the user chooses to re-run it as the other type, **Then** a new result is produced as that type and counts as another import.

---

### User Story 3 - Correct exercise matches and units before accepting (Priority: P1)

Files use abbreviations, misspellings and exercises the user may not have in their catalog, and photos often show weights with no unit. The preview makes clear what the app was unsure of and lets the user resolve it, so an import cannot create junk exercises or badly wrong loads.

**Why this priority**: A wrong exercise splits a lifter's PR history, and a kg/lb mistake produces a dangerous load. Without this step the feature cannot be trusted.

**Independent Test**: Import a file containing one abbreviated exercise, one exercise not in the catalog, and weights with no unit. Confirm each uncertain item is flagged, can be resolved, and that accepting is blocked until the unit is chosen.

**Acceptance Scenarios**:

1. **Given** an exercise name in the file that closely matches a catalog exercise, **When** the preview loads, **Then** that catalog exercise is suggested and the user can change it.
2. **Given** an exercise that is uncertain or not in the catalog, **When** the preview loads, **Then** it is flagged and the user can pick a different exercise or create a new custom one.
3. **Given** a tempo, pause or similar modifier (e.g. "Pause Front Squat"), **When** the file is imported, **Then** it maps to the base lift with the modifier kept as a note, unless a lifter would track a separate PR for that variation.
4. **Given** any absolute weight in the file with no printed unit, **When** the preview loads, **Then** Accept is unavailable until the user chooses kg or lb for those weights.
5. **Given** weights with a printed unit, **When** the file is imported, **Then** the printed unit is used and the user's unit preference does not change the value.
6. **Given** the same new exercise name appears many times in a program, **When** the user accepts, **Then** only one new custom exercise is created and every occurrence uses it.
7. **Given** the user changes the title in the preview, **When** they accept, **Then** the created workout or program uses the changed title.

---

### User Story 4 - Keep using the app while an import runs (Priority: P2)

Reading a file can take a few minutes. The lifter does not have to watch it. They can move around the app or close it, and they find out when the result is ready.

**Why this priority**: Blocking the user for minutes would make the feature frustrating, though the core flow still works without the alert.

**Independent Test**: Start an import, navigate to another screen, and confirm an alert appears when it finishes. Start another, close the app until it finishes, reopen it, and confirm the result is waiting.

**Acceptance Scenarios**:

1. **Given** an import is processing and the app is open, **When** it finishes, **Then** an alert appears on whichever screen the user is on and leads to the review.
2. **Given** an import finished while the app was closed or disconnected, **When** the user returns, **Then** a "Ready to review" card shows the result is waiting.
3. **Given** an import is processing, **When** the user leaves the screen or closes the app, **Then** processing continues and the result is not lost.
4. **Given** an import fails, **When** the user next sees its status, **Then** it shows a plain-language reason and what they can try next.

---

### User Story 5 - Nothing is silently lost (Priority: P2)

Real programs contain things the app cannot represent yet, such as supersets, EMOMs, conditioning work, "exercise A or B" choices and sets with no prescribed load. The lifter sees exactly what could not be structured, and that content stays with the workout or program as notes.

**Why this priority**: Silently dropped work means a lifter trains the wrong session without knowing, but the feature is usable for straightforward programs without it.

**Independent Test**: Import a file containing a superset and a conditioning block. Confirm both are flagged in the preview and appear as notes on the created item.

**Acceptance Scenarios**:

1. **Given** content that cannot be represented as structured sets, **When** the preview loads, **Then** each item is flagged and its original wording is shown.
2. **Given** flagged content, **When** the user accepts, **Then** it is saved as notes on the relevant exercise, day or workout.

---

### User Story 6 - Clear notice, fair limits and control (Priority: P2)

A lifter is told once, before anything is uploaded, that their files are processed by a third-party AI provider. Usage limits are explained when reached. The operator can adjust limits or switch imports off without releasing a new app version.

**Why this priority**: Users must make an informed choice before their files leave the app, and each import has a real cost that has to be bounded before the feature reaches everyone.

**Independent Test**: As a new user, confirm the notice appears before the first upload and not again after accepting. Reach a limit and confirm a clear message appears. Switch imports off and confirm new imports are refused.

**Acceptance Scenarios**:

1. **Given** a user who has never accepted the notice, **When** they begin their first import, **Then** the notice appears before any file is uploaded, naming the AI provider.
2. **Given** a user who declines the notice, **When** they back out, **Then** nothing is uploaded and no import is counted.
3. **Given** a user who accepted the notice, **When** they import again, **Then** the notice is not shown again and their acceptance has been recorded.
4. **Given** a user at their daily or monthly limit, **When** they try to import, **Then** they are told which limit they reached and when it resets, and no file is uploaded.
5. **Given** a user with an import already processing, **When** they try to start another, **Then** they are told to wait for the first one.
6. **Given** the operator has switched imports off, **When** a user tries to import, **Then** they see that the feature is temporarily unavailable.

---

### Edge Cases

- **Not a workout**: a file with no recognisable training content ends with a plain "no workout found" result and counts as an import, because it was fully processed.
- **Illegible content**: readable parts are shown and unclear values are flagged. The app does not invent values it could not read.
- **Too large**: files over the count, size or page limits are refused before upload with a message stating the limit, and do not count.
- **Unsupported or unreadable files**: wrong formats, corrupt files and password-protected PDFs get a specific message and do not count.
- **Disguised files**: a file whose contents don't match an accepted type, such as a program renamed to look like a photo, is deleted before any AI processing and the import fails with a clear message. Uploaded files are never opened, run or shown back to the user by the app.
- **Processing runs out of time**: the import fails with a suggestion to submit fewer pages, and does not count.
- **Processing dies unexpectedly**: an import that has been processing longer than is possible is shown as failed rather than processing forever, and does not count.
- **Double submission of Accept**, including from two devices: exactly one workout or program is created.
- **Accept fails partway**: nothing is created, the preview remains available, and the user can retry.
- **All-percentage programs**: no unit choice is requested, and percentages are kept even if the user has no recorded 1RM for that lift.
- **Mixed units**: printed units apply where printed, and the kg/lb choice applies only to weights with no printed unit.
- **Two sessions in one day**: both are preserved as separate sessions on that day.
- **Instructions embedded in a file** (e.g. text telling the AI to ignore its rules): treated purely as content to read, with no effect on the app or on other users' data.
- **Sign-out during processing**: the import stays with the original account and is not visible to anyone else who signs in on that device.
- **Import switched off during processing**: the running import finishes, and only new imports are refused.
- **Result left unreviewed**: after 7 days the import and its files are removed and the user can no longer review it.
- **Re-run after accept or discard**: not possible, because the files have been removed.
- **No camera available**: the take-a-photo option is not offered on devices or browsers without a usable camera, and choosing a file still works.

## Requirements *(mandatory)*

### Functional Requirements

**Submitting files**

- **FR-001**: Users MUST be able to start an import by taking a photo, choosing one or more images, or choosing one PDF.
- **FR-002**: An import MUST contain either a capped number of images or exactly one PDF, never a mix.
- **FR-003**: System MUST refuse files over the image-count, file-size or page limits before upload and state the limit. Limits MUST be set so an accepted submission can finish within the available processing time.
- **FR-003a**: Only JPEG, PNG, WebP and PDF files MAY be processed. The server MUST confirm each file's type from its actual contents, regardless of its name or declared type, before any AI processing. A file that fails this check MUST be deleted and the import failed with a clear message. The import MUST NOT count against the user's limits, but MUST count toward the limit on uncounted failures. Photos taken in other formats, such as HEIC, MUST be converted to an accepted format on the device before upload.
- **FR-004**: System MUST show the one-time AI-processing notice before a user's first upload, name the provider, and record the acceptance. No file may be uploaded without it.

**Processing**

- **FR-005**: Processing MUST continue independently of the screen or app staying open.
- **FR-006**: System MUST allow each user at most one import processing at a time.
- **FR-007**: System MUST determine whether the content is a single workout or a multi-day program, and MUST let the user re-run the same files as the other type until they accept or discard.
- **FR-008**: System MUST extract the title, weeks, days, rest days, exercises, sets, rep counts and ranges, absolute and percentage loads and ranges, the lift a percentage is based on, target effort, and notes, wherever present.
- **FR-009**: System MUST NOT fabricate values that are not in the source. Unreadable values MUST be left empty and flagged.
- **FR-010**: Uploaded content MUST be treated as untrusted data. It MUST NOT be able to trigger any action, read other data, or cause anything beyond producing its own preview.
- **FR-011**: Every result MUST be validated against the app's rules for workouts, programs and sets before it can be shown for review.
- **FR-012**: An import that has exceeded the maximum possible processing time MUST be treated as failed.

**Finding out it finished**

- **FR-013**: While the app is open, System MUST alert the user on any screen when an import finishes or fails.
- **FR-014**: When the user returns to the app, System MUST show any imports ready for review or failed since they left, including any finished while the app was disconnected.

**Review and accept**

- **FR-015**: System MUST show a read-only preview of the extracted result, including the detected type, before anything is created.
- **FR-016**: Users MUST be able to edit the title in the preview.
- **FR-017**: System MUST suggest the closest catalog exercise for each extracted exercise and flag uncertain or unknown ones. Users MUST be able to choose a different exercise or create a custom one.
- **FR-018**: Tempo, pause and similar modifiers MUST map to the base lift with the modifier saved as a note, unless a lifter would track a separate PR for that variation.
- **FR-019**: Printed units MUST be used where present. If any absolute weight has no printed unit, System MUST block Accept until the user chooses kg or lb for those weights.
- **FR-020**: Content that cannot be represented as structured data MUST be flagged in the preview with its original wording and saved as notes on accept.
- **FR-021**: Accept MUST create the workout or program and any new custom exercises completely or not at all, and MUST create exactly one result however many times it is submitted.
- **FR-022**: Created workouts and programs MUST be private and owned by the user, and MUST open in the existing editors after accept.
- **FR-022a**: Imported workouts and programs MUST permanently remain private. They MUST NOT be publishable to Community, and anything derived from them (duplicates, repeated sessions, program runs) MUST carry the same restriction. Users MUST see that an imported item cannot be made public.
- **FR-023**: Accepting a program MUST NOT start it.
- **FR-024**: Discarding MUST create nothing.

**Limits and control**

- **FR-025**: System MUST enforce per-user daily and monthly import limits, initially 5 per day and 30 per month.
- **FR-026**: Limits MUST be changeable, and imports MUST be able to be switched off for everyone, without releasing a new app version.
- **FR-027**: Limits MUST be enforced by the server and MUST NOT be bypassable by a modified client or by altering import records directly.
- **FR-028**: Imports that are fully processed count against limits, including re-runs and "no workout found" results. Imports refused before processing, and imports that fail because of a problem on the service's side, MUST NOT count. Uncounted failures MUST have their own per-user daily limit, so that misreporting failures cannot provide unlimited processing.
- **FR-029**: System MUST record each import's duration and AI usage so that limits and costs can be reviewed.

**Privacy and retention**

- **FR-030**: Uploaded files and import results MUST be accessible only to the user who submitted them.
- **FR-031**: Uploaded files MUST be deleted when the user accepts or discards the import.
- **FR-032**: Files and results of imports not accepted or discarded within 7 days MUST be removed automatically.
- **FR-033**: After removal of files and results, System MAY retain only the minimal usage record needed to enforce limits and review costs.
- **FR-034**: User data held by imports MUST be included when a user's account is deleted.

### Key Entities

- **Import**: One submission by one user. Holds its status (processing, ready to review, failed, accepted, discarded), detected and requested type, failure reason, timing and AI usage, and whether it counts against limits.
- **Uploaded File**: A photo or PDF belonging to one import, private to its owner and short-lived.
- **Extracted Result**: The proposed workout or program, with flags for uncertain exercises, unread values, missing units and content that could not be structured.
- **Import Limits**: The current daily and monthly limits, file limits and the on/off switch, applying to all users.
- **AI Processing Notice Acceptance**: A record that a user accepted the notice, and when.
- **Workout / Program / Exercise** (existing): What an accepted import creates. Behaves like content the user built by hand, except that imported workouts and programs can never be made public.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from a photo of a single workout to a saved workout in under 2 minutes, including review.
- **SC-002**: At least 95% of successful single-workout imports are ready for review within 60 seconds.
- **SC-003**: On a benchmark set of representative real files, at least 90% of sets are extracted with correct reps and load before user correction.
- **SC-004**: On the benchmark set, no weight is saved in the wrong unit and no file content is silently omitted.
- **SC-005**: At least 95% of files within the published limits finish without a timeout.
- **SC-006**: No import remains shown as processing beyond the maximum possible processing time.
- **SC-007**: No user can exceed their limits or view another user's files or results in security testing.
- **SC-008**: All files for accepted, discarded and abandoned imports are gone within 24 hours of the point they become eligible for removal.
- **SC-009**: At least 80% of imports that reach review are accepted rather than discarded during the first month after launch.

## Assumptions

- All signed-in users receive the feature at release, with no allowlist. The off switch and the benchmark set are the safeguards for launching without a staged rollout.
- The initial limits (5 per day, 30 per month) can be tuned after launch using recorded usage.
- Image-count and PDF-page limits are set from measured processing times on the current service plan, and may be raised if the plan changes. Very long programs may not fit in the first release.
- Daily and monthly limits reset by the calendar in UTC so that behaviour is the same on every device.
- Notifications reach users only while the app is open or when they return. Push notifications while the app is closed are out of scope.
- Full editing of sets in the preview is out of scope. Users correct anything else in the existing editors after accepting.
- Imported items carry no copy attribution, but they stay private permanently because a file may be someone else's copyrighted program. This also means users cannot publish programs they wrote themselves and imported.
- Anything #66 (no-load sets) and #67 (exercise choices) add later can be structured by imports in a future change. Until then that content is preserved as notes.
- Supersets, EMOMs and conditioning work are not added to the data model by this feature.
- Billing or paid tiers are out of scope.
- Uses the existing sign-in, exercise catalog, workout and program editors, and unit preference.
- Delivery is staged so that nothing is visible to users until the final launch stage. The stages and technical design are tracked in GitHub issues and in the implementation plan.
