# MyGrowth Diet Plan — Complete AI Coding Agent Build Specification

## Mandatory Frontend Technology Requirement

**The frontend MUST be built with Flutter using Dart. Do not build the frontend with React, Next.js, Vue, plain HTML/CSS/JavaScript, or TypeScript.** Use Flutter/Dart for the user-facing application and responsive layouts. Target Android and iOS, and support Flutter Web if the chosen architecture and deployment setup allow it. Keep the backend separate from the Flutter frontend.

Recommended architecture:
- **Frontend:** Flutter + Dart, with a maintainable feature-based folder structure.
- **Backend:** Node.js + Express using JavaScript (unless the project owner explicitly changes this requirement).
- **Database:** PostgreSQL.
- **API:** REST API using JSON, with documented authentication and authorization.
- **File/media storage:** Use a suitable object-storage service for uploaded PDFs, audio, images, and other materials; store file metadata and URLs in PostgreSQL.
- **State management:** Choose a widely supported Flutter approach (such as Riverpod or Provider) and use it consistently.
- **Navigation:** Use a consistent Flutter routing solution and protect authenticated/admin routes.
- **Forms and validation:** Implement client-side validation in Flutter and repeat all important validation on the backend.

The coding agent must create and run the Flutter project, configure the required environment settings, implement the actual screens and API integration, and document commands for running the app locally and building Android/iOS/Web targets. Do not deliver only mockups or static screens.


## 1. Instructions to the Coding Agent

You are a senior full-stack software engineer, product designer, database architect, security engineer, and QA engineer. Build a complete, production-minded web application named **MyGrowth Diet Plan** for **Healings Erhuvwuigho Azuike Ministry**.

This is not a request for a mockup, static prototype, or collection of disconnected screens. Build a working application with a functional frontend, backend, database, authentication, role-based authorization, content management, activity tracking, reports, prayer-partner scheduling, and notifications.

Work directly in the project repository. First inspect the existing files and determine whether a project already exists. Preserve working code and conventions where reasonable. Do not overwrite an existing project blindly. If the repository is empty, scaffold the project using the architecture below.

**Do not stop after creating a plan.** Implement the application, run available checks, fix errors, and document anything that genuinely requires credentials or a third-party service. Do not claim a feature works unless it has been implemented and tested to a reasonable degree.

When details are not specified, use the sensible defaults in this document. Do not interrupt implementation for minor design decisions. Keep the code modular and make future additions possible.

---

## 2. Product Overview

- **Product name:** MyGrowth Diet Plan
- **Programme name:** Growth Diet Plan 2027
- **Ministry:** Healings Erhuvwuigho Azuike Ministry
- **Primary purpose:** Help members build consistent spiritual-growth habits, access ministry-approved resources, set personal goals, connect with prayer partners, record activities, and submit accountability reports.
- **Initial programme year:** 2027
- **Future years:** Support 2028 and subsequent years without code changes to the programme content.
- **Default locale/time zone:** English; Africa/Lagos.
- **Currency:** Not required for the core product.
- **Primary device:** Mobile phones, with full desktop and tablet support.
- **Application type:** Flutter application targeting Android and iOS, with Flutter Web support where feasible. Make each supported platform feel native to its screen size and interaction patterns.

### Product principles

1. Encourage consistency, grace, reflection, and growth—not shame or punishment.
2. Make routine tasks easy for members with limited technical experience.
3. Let authorised administrators manage all official programme content through the UI; do not hardcode annual content into components.
4. Protect members’ private reflections, prayer requests, and reports.
5. Make all important actions save reliably and show clear success/error states.
6. Keep accessibility, security, maintainability, and mobile usability central to implementation.

### Suggested tagline

**Growing in the Word. Consistent in Prayer. Accountable in Purpose.**

---

## 2A. Mandatory UI/UX Reference Image Instructions

There is an image inside the project folder that must be inspected and used as a visual reference for the application's UI/UX. This image is inspiration, not a screen to copy exactly.

### Before designing
1. Inspect the project directory and locate the relevant image file.
2. Open and carefully study the image before making major frontend design decisions. If there are multiple images, identify the one that best represents the intended UI/UX reference and note which file was selected.
3. Analyse its layout, navigation, information hierarchy, spacing, colour use, typography, components, and user flows.
4. If the image cannot be found or opened, report that clearly and continue with a polished design appropriate for MyGrowth Diet Plan; do not pretend to have inspected it.

### Use the reference creatively — do not clone it
- Do not reproduce the reference pixel-for-pixel or copy every component exactly.
- Preserve only useful ideas and improve them with current design practices, better usability, clearer hierarchy, and a distinctive identity for MyGrowth Diet Plan.
- Do not assume the reference's layout is suitable for every screen or device. Adapt it thoughtfully for mobile, tablet, and desktop/web.
- Avoid a dated, cluttered, generic dashboard or an overly decorative religious interface.

### Design direction
Create a modern, premium-quality, calm, uplifting, welcoming, and easy-to-use spiritual-growth experience. Use a coherent design system with consistent colours, typography, spacing, iconography, buttons, cards, forms, and feedback states. Use accessible contrast, readable text, clear touch targets, and intuitive navigation. Add subtle animations only where they improve clarity or feedback. Include polished loading, empty, error, success, and confirmation states.

Use progress indicators, calendars, activity checklists, goal summaries, and charts only where they help members understand their growth. The design should support prayer, Bible reading, Bible study, fasting, literature, audio messages, goals, prayer partnerships, accountability, and reflection without making users feel ashamed for missed activities.

### Tailor the experience to each role
- **Main Admin:** a comprehensive, clear administration experience, including the exclusive Admin Access Management area.
- **Admins:** the same day-to-day management experience as the Main Admin, but without controls to grant/suspend/reactivate administrator access or change the Main Admin.
- **Members:** a welcoming personal dashboard focused on today's activities, progress, upcoming prayer sessions, materials, goals, reminders, and reports.

### Flutter implementation requirements
Implement the design in Flutter/Dart with reusable widgets, a consistent theme, responsive breakpoints, and maintainable feature modules. Flutter Web layouts must be deliberately designed for larger screens rather than simply stretching a phone layout. Follow platform-appropriate interaction patterns on mobile and web. Do not implement the UI in React or any other frontend framework.

### Final design review
Before completion, compare the built interface with the reference image and confirm that it informed the design without being copied exactly. Review all key screens and role-specific flows on supported screen sizes. Fix inconsistent spacing, clipped content, inaccessible contrast, broken layouts, placeholder screens, and nonfunctional UI controls. The finished application must look more modern, polished, intuitive, and professional than the reference while fitting the ministry's spiritual-growth purpose.

---

## 3. Recommended Technology Stack

The backend must use JavaScript, not TypeScript, unless the project owner explicitly changes this requirement. The frontend must use Flutter and Dart as stated above.

### Frontend — Flutter/Dart (mandatory)
- Flutter stable channel and Dart
- Feature-based, maintainable Flutter project structure
- Riverpod or Provider for consistent state management
- GoRouter or another well-maintained routing solution
- Flutter form validation, with server-side validation repeated for all important data
- Reusable theme, typography, spacing, colour tokens, and widgets
- Responsive layouts for phones, tablets, and desktop/web
- A chart package only where charts provide meaningful value
- Use supported Flutter packages for file selection, audio playback, notifications, and other platform-specific needs where appropriate

Do not introduce React, Vite, React Router, Tailwind CSS, or JavaScript/TypeScript frontend code as the UI implementation. Flutter Web is still Flutter/Dart.

### Backend
- Node.js
- Express
- JavaScript
- REST API with documented request/response formats
- Centralised error handling and request validation

### Data and services
- PostgreSQL
- Prisma ORM, or another well-maintained ORM if the existing project already uses one
- Supabase Auth and Supabase Storage are recommended for managed authentication and file storage, OR implement secure backend authentication if Supabase is not being used. **Choose one coherent authentication strategy; do not build competing authentication systems.**
- If using Supabase Auth, verify tokens on the backend and enforce authorization on the backend/database. Never rely only on frontend role checks.
- Use object storage for uploaded files. Store storage paths and metadata in PostgreSQL, not large file binaries in database rows.
- Use an email provider such as Resend when configured; create a provider abstraction so another provider can be substituted.
- Use a reliable scheduled-job approach for reminders. It must not depend on a browser tab being open. For production, use a persistent scheduler/worker or a platform cron service that invokes a protected endpoint.
- GitHub for version control.

### Suggested deployment
- Frontend: Vercel
- Backend/API and worker: Render or equivalent
- Database: Neon or Supabase PostgreSQL
- File storage: Supabase Storage or compatible private object storage

Do not commit credentials. Create `.env.example` files and explain all variables in the README.

### Suggested repository layout

If starting from an empty repository, use a structure similar to:

```text
mygrowth-diet-plan/
  Frontend/
    mygrowth_app/
      lib/
        app/
        core/
          config/
          routing/
          theme/
          network/
          widgets/
          utils/
        features/
          auth/
          dashboard/
          programme/
          materials/
          activities/
          goals/
          prayer_partners/
          reports/
          reflections/
          notifications/
          admin/
        main.dart
      assets/
        images/
        icons/
      test/
      pubspec.yaml
      .env.example
  Backend/
    backend/
      src/
        config/
        middleware/
        modules/
          auth/
          users/
          programmes/
          materials/
          activities/
          goals/
          prayer-partners/
          reports/
          reflections/
          notifications/
          announcements/
          admin/
        jobs/
        services/
        utils/
        app.js
        server.js
      prisma/
        schema.prisma
        seed.js
      .env.example
      package.json
  docs/
    API.md
    DEPLOYMENT.md
    SECURITY.md
  README.md
  .gitignore
```

You may adapt this structure if the repository already has a clear convention.

---

## 4. User Roles and Authorization

Implement strict, server-enforced role-based access control (RBAC) with exactly three account roles:

1. **Main Admin** — one and only one primary administrator for the application.
2. **Admin** — additional administrators created or added by the Main Admin to help manage and support the ministry programme.
3. **Member** — every other registered user.

Do not create separate Pastor, Ministry Admin, Coordinator, Super Admin, or other administrative roles. The Main Admin and Admin have the same day-to-day programme-management capabilities, except that only the Main Admin controls administrative access and administrator account status.

### 4.1 Main Admin (exactly one)
The Main Admin has full access to all application administration and programme-management functions, including:
- Create, edit, publish, archive, and manage annual programmes.
- Manage monthly, weekly, and daily plan content.
- Upload, organise, and manage programme materials and external links.
- Manage member accounts, membership status, and member support.
- Configure report questions, activity types, and notification defaults.
- View programme-wide analytics and submitted accountability reports, subject to the stated privacy rules.
- Review reports, add comments, request follow-up, and mark reports reviewed.
- Manage prayer-partner requests and safety reports.
- Create and manage announcements, notifications, and application settings.
- View audit logs and authorised programme data.
- Create/add other Admin accounts, grant or activate their administrative access, suspend or reactivate their access, and review their status.
- See which Admin created an item or made a change where audit tracking applies.

The Main Admin account must be unique and protected. The application must prevent creation of a second Main Admin, prevent the Main Admin role from being assigned through public registration, and prevent an Admin or Member from promoting themselves or another account to Main Admin.

### 4.2 Admin (additional administrator)
An Admin can perform the same day-to-day ministry and application management tasks as the Main Admin, including:
- Manage annual programmes and all monthly, weekly, and daily plans.
- Upload, edit, organise, publish, and archive programme materials and external links.
- Manage Members and provide member support, including permitted account-management actions for Member accounts.
- View and review submitted accountability reports, add comments, request follow-up, and mark reports reviewed.
- View programme analytics and authorised reports, following privacy rules.
- Manage activity definitions, goals/templates, prayer-partner workflows, announcements, and notification settings.
- Manage application content and settings needed to run the programme.
- View audit logs for programme and content-management activity.

An Admin **must not** be able to:
- Create another Admin or assign an administrative role to a Member.
- Grant, activate, restore, suspend, deactivate, or revoke another Admin's administrative access.
- Change any user's role to Main Admin.
- change, suspend, delete, or take control of the Main Admin account.
- Change the identity of the Main Admin or transfer Main Admin ownership.
- Modify or bypass the access-control rules that reserve administrator management for the Main Admin.

Admin accounts added by the Main Admin must remain unable to access administrative tools until the Main Admin explicitly grants/activates their access. When an Admin is suspended, block their authenticated administrative access immediately (including existing sessions/tokens where feasible) without deleting their historical actions or records. The Main Admin can later reactivate them. Preserve an audit trail for administrator creation, access grants, suspension, reactivation, and attempted unauthorised access.

### 4.3 Member
Every public registration must create a Member account only. Members can:
- Manage their own profile and preferences.
- View published programmes and materials.
- Record their own activity completion and progress.
- Set and update their own weekly/monthly goals.
- Submit and view their own reports.
- Create and manage their private reflections.
- Create and manage their own testimony visibility.
- Set prayer availability, request a prayer partner, and manage accepted partnerships.
- Schedule and record prayer sessions with an accepted partner.
- Receive notifications and configure preferences.
- Export their own reports where supported.

### 4.4 Authorization and security rules
- Enforce permissions on the backend for every read, create, update, delete, publish, suspend, and administrative-access action. Frontend visibility rules are not security controls.
- Use a securely constrained role field or equivalent model with only `MAIN_ADMIN`, `ADMIN`, and `MEMBER` roles.
- Enforce the single-Main-Admin invariant in the backend/database and in the initial setup process; concurrent requests must not create two Main Admins.
- Only the Main Admin may create Admin accounts or grant, activate, suspend, reactivate, or revoke Admin access.
- Public registration must always assign `MEMBER`; never accept a role from client-submitted registration data.
- An Admin may manage programme content and Members but may not manage administrative access or alter another Admin's status.
- Never trust a `role`, `userId`, `ownerId`, or similar value sent by the client without checking it against the authenticated identity and database.
- A Member cannot access another Member’s private report, reflection, journal, testimony, goals, or activity records.
- Prayer-partner information is limited to the relevant users and authorised administration/safety workflows.
- Protect against insecure direct object references (IDOR); validate permissions for every object and operation.
- Use least-privilege access by default and log sensitive administrator actions with actor, target, timestamp, action, and outcome.
- Do not expose private journal entries to admins through analytics. Submitted accountability reports must clearly state their visibility before submission.

---

## 5. Authentication and Onboarding

Implement:
- Registration with name, email, password (if using password authentication), and any genuinely necessary profile fields.
- Login and logout.
- Email verification when supported by the chosen provider.
- Password reset.
- Session persistence and secure token handling.
- Protected routes.
- Clear loading, validation, success, and error states.
- Main Admin-controlled suspension/deactivation for Admin accounts and permitted account-management actions for Members.
- A profile completion flow after first login.
- A privacy notice and links to terms/privacy information.

Do not allow public self-registration to assign an admin role. New registrations must always become `MEMBER`. Admin access can only be created and granted by the existing Main Admin. The Main Admin role can only be assigned during a documented, secure, one-time bootstrap procedure.

If ministry membership approval is enabled, new members can have a `PENDING` status until approved. Make the approval requirement configurable.

Provide a safe, documented, one-time Main Admin bootstrap process (script or protected setup command). Enforce that only one Main Admin can ever exist, and do not hardcode a production admin password. Once the Main Admin is established, no normal UI or API action may create a second Main Admin.

Seed demo accounts only in development, with clearly documented temporary credentials and instructions to change them. Never create a known default administrator password in production.

---

## 6. Application Layout and Navigation

Create separate responsive layouts for members and administrators.

### Member navigation
- Dashboard
- My Growth Plan
- Daily Diet
- Bible Reading
- Study Materials
- My Goals
- Fasting Tracker
- Prayer Room
- Accountability Reports
- Reflections & Testimonies
- My Progress
- Notifications
- Profile & Settings

On mobile, use a compact bottom navigation for the most common areas plus an accessible menu for the rest.

### Admin navigation
- Admin Dashboard
- Admin Access Management (Main Admin only: create/add Admin accounts, grant/activate access, suspend/reactivate access, and view administrator status)
- Members
- Annual Programmes
- Monthly Plans
- Weekly/Daily Plans
- Materials Library
- Activity Management
- Reports & Reviews
- Prayer Partnerships
- Announcements
- Notifications
- Analytics
- Audit Logs
- Settings

Show Admin Access Management only to the Main Admin. Hide unavailable navigation items based on role, but remember that hiding a link is not security: enforce permissions on the server too.

---

## 7. Visual Design Requirements

Use a calm, polished, contemporary design appropriate for a spiritual-growth application.

### Design direction
- Primary: deep navy blue
- Secondary: warm gold
- Background: white and soft neutral grey
- Success accent: restrained green
- Typography: readable sans-serif with clear hierarchy
- Cards: subtle borders, restrained shadows, generous spacing
- Icons: consistent, accessible icon set
- Responsive layout: mobile-first
- Use loading skeletons, empty states, confirmation dialogs, toast messages, and clear form validation.
- Avoid clutter, excessive gradients, distracting animation, or childish gamification.
- Meet WCAG-oriented basics: semantic HTML, keyboard navigation, visible focus, labels, sufficient contrast, accessible dialogs, and reduced-motion support.

### Member dashboard
Show:
- Welcome message.
- Current programme year and month.
- Today's scheduled activities.
- Daily affirmation.
- Monthly prayer focus and confession.
- Progress for weekly/monthly goals.
- Next prayer-partner session.
- Reports due or overdue.
- Recent materials and announcements.
- A simple progress summary.

Do not fabricate spiritual scores or imply that an activity completion percentage measures a person's spiritual worth. Label metrics clearly as recorded participation or plan completion.

### Admin dashboard
Show:
- Total registered members.
- Members active during a selected period.
- Weekly/monthly reports submitted and outstanding.
- Reports awaiting review.
- Aggregate activity completion.
- Prayer sessions scheduled/completed.
- Recent sign-ups and announcements.
- Filters by year, month, week, and status.

All dashboard numbers must come from real database queries. Do not hardcode sample metrics into production views.

---

## 8. Programme Content Model

The programme must be data-driven and editable through the admin dashboard.

Use the hierarchy:

**Annual Programme → Month → Week → Day/Activity**

Support multiple years and preserve historical records.

### Annual programme fields
- Title
- Year
- Ministry name
- Description
- Annual prayer focus
- Daily affirmation
- Start/end dates
- Status: draft, published, archived
- Created/updated by
- Publication timestamps

### Monthly plan fields
- Month/year
- Theme or study topic
- Prayer focus
- Bible-reading guidance
- Literature list
- Audio-message list
- Fasting guidance/schedule
- Monthly confession
- Monthly goals guidance
- Reflection questions
- Publication status

### Weekly plan fields
- Week number and actual start/end dates
- Bible reading (books, chapters, or text)
- Prayer-duration target, if set
- Book-reading assignment
- Fasting schedule or reference
- Key lesson prompt
- Memory verse
- Study materials
- Audio materials
- Optional extra activities
- Publication status

### Daily activity fields
- Title and description
- Activity type
- Date or recurrence rule
- Start time and optional duration
- Related material
- Completion instructions
- Whether completion tracking is enabled
- Whether a member note is allowed
- Status and sort order

The calendar must use real dates. Do not assume every month contains exactly four weeks. The year 2027 starts on Friday, January 1. Generate calendar dates correctly using Africa/Lagos as the default time zone.

The system must not invent an official daily Bible-reading schedule, prayer-duration target, or programme instruction when one has not been supplied. The admin must be able to enter the approved schedule. Where only monthly reading guidance exists, display it as monthly guidance until detailed daily assignments are added.

### Programme versioning
- Published content edits should not silently destroy historical records or change completed activity data.
- Record creator/editor and timestamps.
- Consider revisions or an audit log for changes to published content.
- Preserve archived programmes for historical review.
- Members should be able to switch between programme years when those years are available to them.

---

## 9. 2027 Programme Content to Seed

Create the 2027 programme and seed the supplied content below. Treat these as initial draft/published programme data that administrators can edit. Preserve the meaning and wording as closely as possible; correct only obvious formatting issues without changing the ministry's intended message.

### Annual content

**Programme title:** Growth Diet Plan 2027  
**Ministry:** Healings Erhuvwuigho Azuike Ministry

**2027 Prayer Focus:**

“In the name of the Lord Jesus, I walk in the will, plan, and purpose of God for my life. My steps, stops, and turns are divinely orchestrated, I experience furtherance, favor, divine relationships, and supernatural help throughout 2027.”

**Daily Affirmation:**

“I affirm that goodness and mercy follow me all the days of my life. I am healed, favored, protected, provided for, promoted, and divinely guided. Angels guard my path, and God is working all things together for my good.”

### January
- Prayer focus: Spend hours praying in the Spirit throughout the whole month.
- Bible reading guidance: Matthew | Mark | Proverbs
- Study topic: The Fatherhood of God
- Audio messages: God as Father 1–5 by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *The Father and His Family* — E. W. Kenyon; *The 7 Habits of Highly Effective People* — Stephen Covey
- Confession: “My path is a shining light, and it shines brighter and brighter unto a perfect day. Pro 4vs1”
- Reflection questions:
  1. What progress did I make spiritually this month?
  2. What did God teach me this month?
  3. What habits strengthened my walk with God?
  4. What challenges hindered my growth?
  5. What will I improve next month?
  6. What testimonies can I record?

### February
- Prayer focus: I have the discipline and character required for God's purpose for my life.
- Bible reading guidance: Luke | John | Proverbs
- Study topic: God's Purpose for Man
- Audio messages: Plan, Purpose, Pursuit 1–4 by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Plan, Purpose and Pursuit*; *Following God's Plan for Your Life* — Kenneth E. Hagin
- Confession: “Thy word is a lamp unto my feet and a light unto my path. Psalm 119vs105”
- Reflection questions:
  1. What is driving my consistent desire to keep up with my diet plan?
  2. Why am I going through the diet plan—is it for growth or to meet up?
  3. What instructions have I received from the Lord this month?
  4. What challenges hindered my growth?
  5. What will I improve next month?
  6. What testimonies can I record?

### March
- Prayer focus: I have furtherance in my life by the Spirit.
- Bible reading guidance: Acts | Romans | Proverbs
- Study topic: Faithful Steward
- Audio messages: Stewards of Christ 1–5 by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Financial Stewardship* — Andrew Womack
- Confession: “Teach me to number my days, that I may apply my heart unto wisdom. Psalm 90vs12”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### April
- Prayer focus: I have eyes that see, ears that can hear, and a heart that perceives.
- Bible reading guidance: 1 Corinthians | 2 Corinthians | Proverbs
- Study topic: The Leading of the Spirit
- Audio messages: Divine Direction 1–5 by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Understanding Divine Direction* — David O. Oyedepo
- Confession: “For by thee, I have run through a troop; and by my God have I leaped over a wall. Psalm 18vs29”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### May
- Prayer focus: “In the name of the Lord Jesus, my faith is right and my honor is right, therefore my receiving is not hindered.”
- Bible reading guidance: Galatians | Ephesians | Ruth | Proverbs
- Study topic: Honor
- Audio messages: Honor to whom it is due 1–4 by Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *The Midas Touch* — Kenneth E. Hagin
- Confession: “No weapon that is formed against me shall prosper; and every tongue that shall rise against me in judgment I shalt condemn. Isaiah 54:17”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### June
- Prayer focus: “In the name of the Lord Jesus, as long as I have breath in my lungs, my life will forever praise the Lord.”
- Bible reading guidance: Philippians | Colossians | Psalms | Proverbs
- Study topic: Understanding Relationships
- Audio messages: Supernatural Relationship 1–5 by Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *A Sailing Ship* — Healings E. Azuike; *Life Together* — Dietrich Bonhoeffer
- Confession: “I am visible to the people who should be in my path, I recognize them and they recognize me, together we are fulfilling Gods plan for my life.”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### July
- Prayer focus: “In the name of the Lord Jesus, I am visible to those who should see me.”
- Bible reading guidance: 1 Thessalonians | 2 Thessalonians | Isaiah | Proverbs
- Study topic: Understanding Wealth
- Audio messages: The Love of God by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *The Psychology of Money* — Morgan Housel; *Giving and Receiving* — Kenneth Copeland
- Confession: “Thou wilt shew me the path of life: in thy presence is fullness of joy; at thy right hand there are pleasures for evermore. Psalm 16:11”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### August
- Prayer focus: “In the name of the Lord Jesus, my name is in the heart of those that matters to what matters to me and I have recommendation that brings about furtherance into my life.”
- Bible reading guidance: 1 Timothy | 2 Timothy | Titus | Ecclesiastes | Proverbs
- Study topic: Believers' Conduct
- Audio messages: The Man in Christ 1–3 by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Atomic Habits* — James Clear
- Confession: “The lines are fallen unto me in pleasant places; yea, I have a goodly heritage. Psalm 16:6”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### September
- Prayer focus: “In the name of the Lord Jesus, I and every member of my family are kept in safety, we are delivered from unreasonable and wicked men.”
- Bible reading guidance: Philemon | Hebrews | James | Joshua | Proverbs
- Study topic: Service to God
- Audio messages: Christian Devotion 1–3 by Pastor Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Spiritually Social* and *The Fear of Failing* — both by Healings E. Azuike
- Confession supplied: “I am generous with Gods resources, I give cheerfully and bountifully, my barn is ever filled with plenty.”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### October
- Prayer focus: “In the name of the Lord Jesus, I am in the right place at the right time at all time, it will not, it shall not, it cannot enter the heart of any man to do me evil.”
- Bible reading guidance: 1 Peter | 2 Peter | 1 John | Exodus | Proverbs
- Study topic: Mentor & Discipleship
- Audio messages: Pass It On 1–4 by Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Scripted Life* — Healings E. Azuike; *Eat This Book* — Eugene H. Peterson
- Confession supplied: “The eyes of my understanding being enlightened; that I may know what the hope of his calling is, and what the riches of the glory of his inheritance in the saints. Eph 1.18”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### November
- Prayer focus: “In the name of the Lord Jesus, I am generous with Gods resources, therefore, at all times, I have seed to sow and bread to eat.”
- Bible reading guidance: 2 John | 3 John | Jude | Genesis | Proverbs
- Study topic: The Gospel
- Audio messages: The Gospel 1–4 by Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: Salvation Classic One & Two — Apostle TD Philips
- Confession supplied: “My life is being shaped by prayer, the more I pray, the more I see a need to pray.”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### December
- Prayer focus: Prayer of thanksgiving.
- Bible reading guidance: Revelation | 1 Samuel | 2 Samuel | Proverbs
- Study topic: The Blessing of God
- Audio messages: The Blessing of Work and Practicing Joy by Healings E. Azuike
- Fasting: Wednesday and Saturday, 6:00 a.m.–2:00 p.m. minimum
- Literature: *Out With It* and *Redefine* — both by Healings E. Azuike
- Confession supplied: “Be careful for nothing; but in everything by prayer and supplication with thanksgiving let your requests be made known unto God. Phil 4:6”
- Reflection questions: Use the standard monthly reflection questions listed for January.

### Quarterly content
Quarterly confession (use for each quarterly review unless admin edits it):

“I am growing in grace, wisdom, discipline, faith, prayer, stewardship, and service. The Word of God is producing results in my life daily. I walk in divine direction and fulfill God's purpose.”

Quarterly review topics:
- Bible reading
- Prayer life
- Stewardship
- Service
- Relationships
- Character growth

### Annual reflection
Provide a private annual reflection and letter-to-oneself form covering:
- Victories
- Lessons learned
- Answered prayers
- Relationships
- Growth areas
- Goals for the following year

**Content quality note:** Some supplied monthly confession texts appear to have been placed under different months in the source document. Seed the supplied monthly text faithfully, but allow the administrator to edit and verify the confession assigned to each month. Do not silently invent corrections. Preserve the supplied fasting schedule as programme guidance and let the ministry decide its exact implementation.

### Weekly plan template
Each month must support weekly entries for:
- Week
- Bible reading / book and chapters
- Prayer duration
- Book reading
- Fasting
- Key lesson
- Memory verse
- Optional study materials and audio messages

Do not populate missing weekly/day-by-day assignments with fabricated official content. Create editable empty entries or clearly label any optional example data as sample content.

---

## 10. Daily Diet and Activity Tracking

Create a daily checklist generated from the published plan and the member's own schedule.

Supported activity categories:
- Prayer
- Scripture reading
- Bible study
- Literature reading
- Proverbs reading
- Fasting and prayer
- Prayer and affirmations
- Confessions and declarations
- Audio message
- Prayer-partner session
- Personal reflection
- Custom administrator-defined activity

Each activity may include:
- Planned date
- Optional start time
- Target duration or quantity
- Completion status
- Actual duration or quantity
- Optional private note
- Completion timestamp

Statuses should include `NOT_STARTED`, `IN_PROGRESS`, `COMPLETED`, `SKIPPED`, and `NOT_APPLICABLE` where suitable.

Members must be able to record activities completed offline. Never imply that the app can verify a private prayer, Bible reading, or fast; activity records are self-reported.

Do not automatically punish or shame members for missed activities. Provide a simple way to record a missed activity or explain a challenge.

Prevent duplicate completions for the same user/activity/date unless the activity explicitly supports multiple sessions.

---

## 11. Goals and Progress Tracking

Members can create weekly and monthly goals.

### Goal fields
- Title
- Description
- Period type: weekly or monthly
- Start date
- Target date
- Target quantity and unit, when applicable
- Current progress
- Status: active, completed, paused, abandoned
- Private notes
- Created/updated timestamps

Allow up to three suggested monthly goal slots to match the supplied programme, while also allowing additional goals if enabled by the administrator.

Examples shown in the UI may include reading progress or prayer-session targets, but do not present invented targets as official ministry requirements.

Calculate progress from stored activity data where possible; otherwise let the member update it manually. Prevent progress from exceeding logical limits unless the goal type supports it.

Provide weekly and monthly review prompts, completed/partial/not-completed status, and a record of lessons learned.

---

## 12. Study Materials Library

Administrators can upload files or add external links.

### Supported content
- PDF/document
- Audio message
- Video
- Bible study notes
- Literature reference
- Prayer guide
- Scripture reading link
- Confession/declaration
- Announcement
- Other resource

### Material fields
- Title
- Description
- Category
- Programme year
- Month/week/day association, if any
- File storage path or external URL
- Thumbnail/cover image
- Author/speaker
- Publication date
- Visibility/access settings
- Optional completion tracking
- Draft/published/archived status
- Created/updated by

### Material features
- Search by title and keyword.
- Filter by category, month, year, and type.
- Sort by newest, title, or programme order.
- Open/download authorised files.
- Listen to supported audio formats with a usable player.
- Embed external content only when the provider permits it; otherwise show a safe external link.
- Mark material as completed.
- Save materials to a personal reading list if practical.
- Show empty/loading/error states.

Validate upload file type and size on both client and server. Use signed/temporary URLs for private files where supported. Do not expose private storage credentials. Sanitize and validate external URLs to reduce unsafe-link risks. Avoid accepting executable uploads.

For copyrighted books, allow authorised files or links to legitimate sources; do not seed pirated book PDFs.

---

## 13. Prayer Partner System

Build a complete opt-in partner workflow.

### 13.1 Availability
Members can set:
- Availability: available, unavailable, temporarily unavailable
- Available days
- Preferred time ranges
- Time zone
- Preferred session duration
- Optional preferred language
- Whether they accept new partner requests

Do not expose exact personal schedules to all users. Show only the information needed to find a compatible partner.

### 13.2 Discover and request
- Provide a “Find a Prayer Partner” screen.
- Show only members who have opted in and are available.
- Filter by overlapping availability, time zone, and preferred duration.
- Allow a member to send a request with an optional message.
- Recipient can accept, decline, or block/report.
- Do not create an active partnership until accepted.
- Prevent duplicate active requests/partnerships where inappropriate.
- Notify both users about status changes.

### 13.3 Partnership management
- Show current partner and partnership status.
- Allow either user to pause or end the partnership.
- Require confirmation before ending.
- Provide block/report controls.
- Give admins a restricted safety-management view for reports.
- Record significant partnership actions in audit logs.

### 13.4 Prayer sessions
A session includes:
- Partnership
- Proposed by
- Date
- Start time
- Duration
- Time zone
- Prayer focus (optional)
- Meeting method/link (optional)
- Status: proposed, accepted, completed, rescheduled, cancelled, missed
- Optional participant notes with clear visibility rules

Either participant may propose a session. The other participant must accept before it is considered confirmed. Both participants can record their attendance/completion. Make it clear that completion is self-reported.

### 13.5 Scheduling
- Store timestamps consistently (UTC in database where appropriate).
- Display dates/times in the user's configured time zone.
- Use Africa/Lagos by default.
- Handle daylight-saving changes for other time zones through a robust date/time library.
- Prevent conflicting sessions where reasonable.
- Send configurable reminders before accepted sessions.

Do not build unmoderated public chat in the first release unless specifically required. If messaging is implemented later, add blocking, reporting, abuse controls, and privacy safeguards.

---

## 14. Accountability Reports

Implement weekly, monthly, quarterly, and annual report types.

### Report lifecycle
`DRAFT → SUBMITTED → REVIEWED` or `REQUIRES_FOLLOW_UP`

Allow a member to edit a draft. Once submitted, editing should follow a clear policy. If editing after submission is allowed, preserve revision history or notify the reviewer. Do not silently overwrite reviewed reports.

### Weekly report fields
- Week and programme association
- Planned activity summary
- Bible-reading progress
- Prayer participation/duration (self-reported)
- Literature-reading progress
- Bible-study participation
- Fasting participation, where scheduled
- Audio-message participation
- Goals and status
- What did I learn this week?
- Which Scripture impacted me most?
- What progress did I make?
- What challenges did I encounter?
- What will I improve next week?
- Optional testimony
- Submitted timestamp

### Monthly report fields
- Month/programme association
- Three or more monthly goals and their status
- Bible-reading progress
- Prayer activity summary
- Literature-reading progress
- Fasting participation, where scheduled
- Study/audio participation
- Lessons learned
- Challenges
- Improvements for next month
- Testimony
- Configurable monthly reflection questions and answers

### Quarterly review
Include:
- Bible reading
- Prayer life
- Stewardship
- Service
- Relationships
- Character growth
- Progress and challenges
- Lessons learned
- Goals for next quarter
- Quarterly confession display
- Optional testimony

### Annual report
Include:
- Victories
- Lessons learned
- Answered prayers
- Relationships
- Growth areas
- Personal goals
- Testimonies
- Letter to oneself for the next year

### Admin review tools
Authorised admins can:
- View submitted reports.
- Add comments.
- Request clarification/follow-up.
- Mark reports reviewed.
- Track review history and timestamps.
- Filter by programme, date, member, and status.
- Export authorised reports.

Keep the member's original responses distinguishable from admin comments. Do not let an admin silently rewrite the member's answers.

### Reporting privacy
- Members can view their own reports.
- Administrators can view reports only according to assigned permissions.
- Private journal entries are separate from submitted accountability reports.
- Make report visibility clear before submission.
- Do not make testimonies public by default.

---

## 15. Reflections, Journals, and Testimonies

### Private reflection/journal
Members can create dated entries with a title and body. Entries are private by default. Allow editing and deletion subject to documented retention rules. Do not expose journal text in admin analytics.

### Testimonies
Fields:
- Title
- Date
- Story/body
- Optional tags
- Visibility: private, authorised ministry admins, approved community sharing
- Consent to share
- Approval status if public/community sharing is enabled

Never publish a testimony or reflection without the member's explicit consent and any required approval.

### Annual letter
Provide a rich-text or plain-text editor with save-draft functionality. The annual letter is private by default and must not be shared with the pastor unless the member explicitly chooses to share it.

---

## 16. Notifications and Reminders

Implement an in-app notification centre and a provider abstraction for email. Web push can be added if practical; WhatsApp is a future integration and must not be represented as active until configured and tested.

### Notification events
- Welcome/account verification
- Membership approval, if enabled
- New programme published
- New material published
- Daily activity reminder
- Weekly goal/report reminder
- Monthly goal/report reminder
- Quarterly review reminder
- Annual reflection reminder
- New announcement
- Prayer-partner request received
- Partner request accepted/declined
- Prayer session proposed/accepted/rescheduled/cancelled
- Upcoming prayer session
- Admin report comment/follow-up request

### Notification settings
- Enable/disable email notifications.
- Configure reminder times.
- Choose daily/weekly summary preferences where supported.
- Time zone.
- Quiet hours if practical.
- Do not send repeated reminders excessively.
- Respect user opt-outs for nonessential email.
- Keep security-related messages separate from optional reminders.

### Technical requirements
- Scheduled reminders must run server-side or through a reliable external scheduler.
- Store notification delivery status and errors.
- Avoid duplicate delivery using idempotency keys or a unique event/recipient combination.
- Retry transient provider failures safely.
- Do not log secrets or sensitive message contents.
- Include a protected cron endpoint or worker process with authentication if the deployment platform requires it.
- Document how to configure cron/scheduled jobs.

---

## 17. Announcements

Admins with permission can create announcements with:
- Title
- Body
- Optional link
- Optional attachment/material
- Audience (all members or an authorised group)
- Start/end visibility dates
- Draft/published/archived status
- Creator and timestamps

Members should see active announcements on their dashboard and in a dedicated list. Send notifications according to member preferences and admin settings.

---

## 18. Progress and Analytics

Provide honest, understandable summaries based on recorded data.

### Member analytics
- Daily/weekly/monthly activity completion
- Goal progress
- Bible-reading activity
- Prayer duration recorded
- Literature progress
- Fasting participation recorded
- Reports submitted
- Prayer sessions completed
- Streaks, if implemented
- Historical comparison by month/year

Label metrics as **self-reported** where applicable. Never imply that activity tracking measures spiritual worth, faith, or divine favour.

### Admin analytics
- Total and active members
- Report submission/review status
- Aggregate completion rates by activity type
- Participation over time
- Prayer-partner sessions
- Member engagement trends
- Filters by date and programme year
- Exportable summaries

Use aggregate views where possible. Avoid displaying sensitive personal reflection or prayer-request text in analytics.

---

## 19. Search, Filters, and Pagination

Implement server-side search/filter/pagination for lists that can grow:
- Members
- Materials
- Reports
- Announcements
- Prayer requests/partnerships
- Audit logs

Use validated query parameters, sensible page sizes, stable sorting, and indexes for common filters. Do not fetch an unlimited number of records to the browser.

---

## 20. Suggested Database Entities

Design a relational PostgreSQL schema with appropriate primary keys, foreign keys, constraints, indexes, and timestamps. Adjust names as needed, but cover these concepts:

1. `users` / `profiles`
2. `roles` or a securely constrained role field
3. `annual_programmes`
4. `monthly_plans`
5. `weekly_plans`
6. `daily_activities` / programme activity definitions
7. `materials`
8. `user_activity_records` / activity completions
9. `personal_goals`
10. `goal_progress_entries`
11. `prayer_availability`
12. `prayer_partner_requests`
13. `prayer_partnerships`
14. `prayer_sessions`
15. `reports`
16. `report_answers` or structured report fields
17. `report_reviews`
18. `reflection_entries`
19. `testimonies`
20. `notifications`
21. `notification_preferences`
22. `announcements`
23. `admin_access_events` / `audit_logs` (record Admin creation, access grants, suspension, reactivation, revocation, and other sensitive administrative actions)
23. `audit_logs`
24. Optional `programme_revisions`, `user_groups`, and `group_memberships`

### Data modelling rules
- Use UUIDs or another consistent non-guessable primary key strategy.
- Store creation/update timestamps.
- Use foreign keys and appropriate deletion policies.
- Avoid cascading deletion of historical reports without an explicit retention policy.
- Add unique constraints for one report per user/period/type where appropriate.
- Prevent duplicate prayer-partner requests and duplicate activity records where appropriate.
- Use enums or constrained values for statuses.
- Store timestamps consistently and render in user time zones.
- Store uploaded files as storage keys/paths, not trusted arbitrary filesystem paths.
- Add indexes for `user_id`, programme/year, date, status, and common dashboard queries.
- Include database migrations and a repeatable seed script.
- Document any privacy-sensitive fields and access rules.

---

## 21. API Design

Build a consistent REST API under `/api/v1`. Use JSON, appropriate HTTP status codes, request validation, and consistent error responses.

Suggested route groups:

### Auth/profile
- `GET /api/v1/me`
- `PATCH /api/v1/me`
- Authentication-provider routes as required
- Password reset/verification routes only if handled by the chosen backend

### Users/admin
- `GET /api/v1/admin/users`
- `GET /api/v1/admin/users/:id`
- `PATCH /api/v1/admin/users/:id`
- `POST /api/v1/admin/users/:id/approve`
- `POST /api/v1/admin/users/:id/suspend`
- Admin account creation/access grant/suspension/reactivation/revocation routes restricted to Main Admin only; do not expose any API route that lets an Admin create or manage other Admins or create a second Main Admin

### Programmes
- `GET /api/v1/programmes`
- `GET /api/v1/programmes/:id`
- `POST /api/v1/admin/programmes`
- `PATCH /api/v1/admin/programmes/:id`
- `POST /api/v1/admin/programmes/:id/publish`
- `POST /api/v1/admin/programmes/:id/archive`

### Monthly/weekly/daily plans
- CRUD routes nested under programme/month/week as appropriate
- Published programme routes for members
- Admin-only draft editing/publishing routes

### Materials
- `GET /api/v1/materials`
- `GET /api/v1/materials/:id`
- `POST /api/v1/admin/materials`
- `PATCH /api/v1/admin/materials/:id`
- `POST /api/v1/admin/materials/:id/publish`
- Upload signing/metadata routes as required by storage provider

### Activities/goals
- `GET /api/v1/me/activities`
- `POST /api/v1/me/activity-records`
- `PATCH /api/v1/me/activity-records/:id`
- `GET /api/v1/me/goals`
- `POST /api/v1/me/goals`
- `PATCH /api/v1/me/goals/:id`
- `POST /api/v1/me/goals/:id/progress`

### Prayer partners
- `GET /api/v1/prayer-partners/availability`
- `PUT /api/v1/prayer-partners/availability`
- `POST /api/v1/prayer-partners/requests`
- `PATCH /api/v1/prayer-partners/requests/:id`
- `GET /api/v1/prayer-partners/partnerships`
- `POST /api/v1/prayer-partners/sessions`
- `PATCH /api/v1/prayer-partners/sessions/:id`

### Reports
- `GET /api/v1/me/reports`
- `POST /api/v1/me/reports`
- `PATCH /api/v1/me/reports/:id`
- `POST /api/v1/me/reports/:id/submit`
- `GET /api/v1/admin/reports`
- `GET /api/v1/admin/reports/:id`
- `POST /api/v1/admin/reports/:id/reviews`

### Reflections/testimonies
- Member-owned CRUD routes with visibility and consent enforcement

### Notifications/announcements
- `GET /api/v1/me/notifications`
- `POST /api/v1/me/notifications/:id/read`
- `GET /api/v1/announcements`
- Admin-only announcement CRUD/publish routes

### Analytics/audit
- Admin-only analytics endpoints with permission checks
- Audit-log endpoints available to authorised administrators; administrator-access grant/suspension events may be viewed, but only the Main Admin can perform those actions

These routes are examples, not a demand to implement every endpoint exactly as written. Implement the complete set needed by the actual UI, document them in `docs/API.md`, and ensure every frontend action calls a real endpoint or explicitly displays that the feature is not yet configured.

---

## 22. Security Requirements

Implement production-minded basics:

- Validate all input on the server.
- Use parameterised ORM/database queries.
- Use secure password/authentication provider practices.
- Verify access tokens on protected routes.
- Enforce RBAC and record ownership on the backend.
- Use rate limiting for authentication, uploads, partner requests, and sensitive endpoints.
- Configure CORS for known frontend origins.
- Use secure headers such as Helmet.
- Apply request body size limits.
- Validate upload size, type, and access.
- Avoid unsafe HTML rendering; sanitise rich text if supported.
- Protect against IDOR, mass assignment, privilege escalation, injection, and open redirects.
- Do not expose stack traces or secrets to clients in production.
- Never store secrets in source control.
- Use environment variables for credentials.
- Log operational events without logging passwords, tokens, private reflections, or sensitive prayer content.
- Add audit logs for admin role changes, programme publication, material publication, report review, account suspension, and other significant actions.
- Implement appropriate database backups and document recovery.
- Provide privacy and data-retention documentation.
- Use least privilege for database and storage access.

If using Supabase, configure Row Level Security (RLS) where applicable, and still enforce the required backend checks. Do not expose the service-role key to the browser.

---

## 23. Accessibility, Reliability, and Performance

- Responsive design for small phones, tablets, laptops, and desktop.
- Keyboard accessible controls and forms.
- Labels for all fields.
- Useful empty states and error messages.
- Loading indicators and retry options.
- Confirm destructive actions.
- Use pagination for large lists.
- Lazy-load routes or heavy resources where useful.
- Optimise images and audio loading.
- Avoid blocking the main interface while uploading large materials.
- Show upload progress and actionable failures.
- Prevent duplicate form submissions.
- Make key actions idempotent where practical.
- Handle offline/network failures gracefully.
- Do not claim offline activity synchronisation unless it is actually implemented.
- If implementing PWA/offline support, clearly define what works offline and safely reconcile pending changes.

---

## 24. Testing Requirements

Write and run appropriate tests.

### Backend tests
- Authentication/authorization guards.
- Member can access own records but not another member's private records.
- Member cannot assign themselves an admin role.
- Admin-only programme and material editing.
- Draft/publish/archive workflows.
- Activity completion ownership and duplicate prevention.
- Goal progress calculations.
- Prayer-partner request acceptance/decline.
- Session scheduling and status transitions.
- Report submission and review lifecycle.
- Testimony visibility and consent.
- Notification deduplication.
- Input validation and error handling.

### Frontend tests
- Login/registration form validation.
- Protected route behaviour.
- Role-based navigation.
- Daily activity completion.
- Goal creation and progress update.
- Material search/filter.
- Report draft and submission.
- Prayer-partner request flow.
- Notification read state.
- Loading, empty, and error states.

### End-to-end smoke tests
At minimum, verify this core flow:
1. A member registers/logs in.
2. The member sees a published 2027 programme.
3. The member views the current monthly plan.
4. The member records a daily activity.
5. The member creates a monthly goal.
6. The member saves and submits a weekly report.
7. An authorised admin views and reviews the report.
8. The member sees the review comment.
9. A member sets prayer availability and requests a partner.
10. A second member accepts the request.
11. They schedule and confirm a prayer session.
12. A reminder is queued or sent in a test environment.
13. The admin uploads/publishes a material.
14. The member can find and open it.

Run lint/build/tests that exist. Fix failures before declaring completion. If an external service cannot be tested without credentials, provide a mock/test adapter and clearly document the remaining manual test.

---

## 25. Seed Data and Development Mode

Create a repeatable database seed script that:
- Creates the 2027 Growth Diet Plan.
- Creates all 12 monthly plans from Section 9.
- Creates quarterly review content.
- Creates the annual reflection template.
- Creates appropriate material categories and activity categories.
- Optionally creates development-only sample users and materials.

Do not fabricate official day-by-day Bible-reading allocations, memory verses, prayer-duration targets, or weekly assignments that were not supplied. Leave these editable fields blank or label clearly as examples.

Seed data must be idempotent where possible so rerunning it does not create duplicate programmes or duplicate months.

Development sample users must be disabled in production and must not use publicly known passwords.

---

## 26. Environment Variables and Deployment

Create `.env.example` files with explanations. Expected variables may include:

### Backend
- `NODE_ENV`
- `PORT`
- `DATABASE_URL`
- Authentication provider URL/issuer and public verification key or required provider configuration
- Storage provider URL and server-only credentials, if used
- `FRONTEND_URL`
- `CORS_ORIGINS`
- Email provider API key
- Sender email
- Cron/scheduler secret if a protected scheduled endpoint is used
- Optional logging/error-monitoring configuration

### Frontend
- Public API base URL
- Public auth URL/key if the selected auth provider requires them

Use variable names that match the chosen implementation and document each one. Do not place server-only secrets in Flutter compile-time configuration, mobile binaries, web bundles, or any client-side code. Public client configuration may be supplied through documented Flutter build-time variables; secrets must remain on the backend.

### Deployment checklist
- Install dependencies.
- Configure database.
- Run migrations.
- Run seed script.
- Configure storage buckets and access policies.
- Configure authentication redirect URLs.
- Configure CORS.
- Configure email provider and sender domain.
- Configure scheduled jobs.
- Configure frontend API URL.
- Configure HTTPS/custom domain if applicable.
- Verify health-check endpoint.
- Verify database backups.
- Verify production build.
- Test account recovery and admin bootstrap.
- Confirm no development credentials or debug routes are active.

Create:
- `README.md` with local setup, architecture, scripts, environment variables, seeding, testing, and deployment.
- `docs/API.md` with routes and examples.
- `docs/DEPLOYMENT.md` with Vercel/backend/database/storage/scheduler instructions.
- `docs/SECURITY.md` with roles, privacy model, storage access, and operational security.

---

## 27. Acceptance Criteria

The application is not complete until all applicable criteria below are satisfied:

### Authentication and permissions
- [ ] Users can register, log in, log out, and recover access.
- [ ] Member role is assigned securely by default.
- [ ] Admin roles cannot be self-assigned.
- [ ] Protected backend routes enforce roles and record ownership.
- [ ] Private records cannot be accessed by other members.

### Programme management
- [ ] Admin can create/edit/publish/archive annual programmes.
- [ ] 2027 programme exists with all 12 monthly themes and supplied content.
- [ ] Monthly plans contain editable fields for all required content categories.
- [ ] Weekly and daily assignments can be entered through the admin UI.
- [ ] Calendar dates are generated correctly.
- [ ] Future programme years can be created without code changes.
- [ ] Historical programme data remains available.

### Materials
- [ ] Admin can add an external link and upload a supported file.
- [ ] Admin can edit, publish, archive, and organise materials.
- [ ] Members can search/filter published materials.
- [ ] File access and upload validation are enforced.

### Member activities and goals
- [ ] Members can view daily/weekly/monthly activities.
- [ ] Members can record activity completion and optional notes.
- [ ] Members can create weekly and monthly goals.
- [ ] Progress summaries are calculated from actual stored data.
- [ ] Missed activities can be recorded without punitive language.

### Prayer partners
- [ ] Members can opt into availability.
- [ ] Members can request, accept, decline, pause, and end partnerships.
- [ ] Only accepted partnerships can schedule shared sessions.
- [ ] Session status and time zone handling work.
- [ ] Block/report and admin safety handling exist.

### Reports
- [ ] Members can draft and submit weekly/monthly reports.
- [ ] Quarterly and annual review forms are available.
- [ ] Admins can review reports and add comments.
- [ ] Members can see review status/comments.
- [ ] Private reflections remain separate from submitted reports.
- [ ] Testimonies respect visibility and consent settings.

### Notifications
- [ ] In-app notifications work.
- [ ] Notification preferences are saved.
- [ ] Reminder events can be scheduled server-side.
- [ ] Duplicate reminders are prevented.
- [ ] Email integration is either tested/configured or clearly documented as pending credentials.

### Quality and deployment
- [ ] Frontend production build succeeds.
- [ ] Backend starts correctly.
- [ ] Database migrations and seed scripts run.
- [ ] Core tests pass.
- [ ] No secret credentials are committed.
- [ ] README and deployment docs are complete.
- [ ] Main flows work on mobile and desktop.
- [ ] No major visible button is inert; if a feature is intentionally deferred, it must be clearly marked and documented.

---

## 28. Implementation Order

Follow this order to reduce rework:

1. Inspect repository and report the current stack.
2. Set up project structure and environment configuration.
3. Design database schema and migrations.
4. Implement authentication and RBAC.
5. Build programme models and seed the 2027 content.
6. Build admin programme/content management.
7. Build materials upload/link management.
8. Build member dashboard and published programme views.
9. Build daily activity tracking and goals.
10. Build weekly/monthly/quarterly/annual reports and admin review.
11. Build prayer-partner availability, requests, and sessions.
12. Build in-app notifications and email/scheduler adapters.
13. Build reflections, testimonies, announcements, and analytics.
14. Add responsive Flutter layouts, accessibility, platform-appropriate navigation, and optional offline/PWA support if feasible.
15. Write tests, run build, fix issues, and test core flows.
16. Complete documentation and deployment configuration.

Keep a short `IMPLEMENTATION_STATUS.md` checklist updated as work progresses, noting what is implemented, tested, and still requires external credentials.

---

## 29. Final Instructions

Build the real application, not just a visual concept. Prioritise a reliable end-to-end implementation of authentication, the editable 2027 programme, materials, activity tracking, goals, accountability reports, and the prayer-partner workflow.

Do not:
- Hardcode the entire programme in frontend components.
- Fake database results.
- Leave major buttons without actions.
- expose private records to other members.
- Allow users to promote themselves to administrator.
- Store secrets in source control.
- Invent official weekly or daily assignments that the ministry did not supply.
- Claim email, push, WhatsApp, or scheduled reminders are working without configuration and testing.
- Replace working repository code unnecessarily.
- Stop after producing a plan or attractive dashboard.

At completion, provide a concise handover containing:
1. What was implemented.
2. The chosen stack and architecture.
3. How to run the frontend and backend locally.
4. How to configure the database and storage.
5. How to bootstrap the single Main Admin securely.
6. How to seed the 2027 programme.
7. How to run migrations, tests, and builds.
8. Required environment variables and third-party credentials.
9. Deployment instructions.
10. Known limitations and features that still require configuration.

**Start by inspecting the repository, then implement the application end to end.**