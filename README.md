# GemFund App 💎🚀

**GemFund** is a cross-platform crowdfunding platform designed to **rebuild public trust** amid widespread fraud. Built with **Flutter** for mobile (Android/iOS), web, and desktop, it combines **Gemini AI (Multimodal)** for campaign authenticity verification with **blockchain** for full transaction transparency.

## Screenshots

![Onboarding 1](Screenshot/onboarding%20.jpg)
![Onboarding 2](Screenshot/onboarding%20(1).jpg)
![Onboarding 3](Screenshot/onboarding%20(2).jpg)
![Campaign](Screenshot/campaign.jpg)
![AI Score](Screenshot/AI%20score.jpg)

## Background & Challenges Faced
The crowdfunding industry is facing a **serious crisis of trust** due to rampant fraud. According to the **FBI Internet Crime Complaint Center (IC3) 2024**, there were more than 4,500 complaints related to fraudulent charities, crowdfunding accounts, and disaster relief campaigns, resulting in approximately **$96 million** in losses in the United States alone. Globally, donors struggle to verify the authenticity of images and stories, lack transparency in fund usage, and fraud is often only detected after campaigns end.

Studies in the *Journal of Business Ethics* highlight that conventional platforms have weak enforcement because campaign creators have no legal obligation to provide financial reports, allowing a single fraud case to damage the reputation of the entire ecosystem.

**Key challenges donors face:**
- Difficulty verifying images (deepfakes, stock photos, AI-generated content)
- Lack of transparency in fund flows
- Manual analysis of too many campaigns

## GemFund's Innovative Solution
GemFund combines the power of **Gemini AI Multimodal** + **blockchain technology** to address the root issues:

- **Gemini AI (Multimodal)**: Automatic campaign authenticity verification  
  - Detects fake images, stock photos, and AI-generated content  
  - Analyzes text for red flags, unrealistic promises, and story inconsistencies  
  - Provides a **Trust AI Score** + detailed forensics report

- **Blockchain**: Absolute transparency  
  - All donation transactions are recorded immutably and verifiable by anyone  
  - Smart contracts automate disbursement (e.g., upon milestone achievement)  
  - Eliminates intermediaries and risks of fund manipulation

This combination enables donors to **trust 100%** before contributing, while giving campaign creators higher credibility.

## Key Features (Update as Progress Continues)
- User authentication & management via Supabase
- Create & manage fundraising campaigns
- AI-powered verification (Gemini integration) with Trust AI Score & forensics
- Blockchain tracking of donation transactions (real-time verifiable ledger)
- Transparent fund dashboard (progress, usage breakdown)
- Secure donations + full transaction history
- Cross-platform: Mobile, Web, Desktop
- Dark mode & modern UI

## Tech Stack
- **Frontend**: Flutter (Dart) – cross-platform excellence
- **AI Verification**: Google Gemini API (Multimodal for image + text analysis)
- **Backend & DB**: Supabase (Auth, Realtime, Storage)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Gemini AI](https://img.shields.io/badge/Gemini%20AI-4285F4?style=for-the-badge&logo=google&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

## Local Installation & Run
```bash
# Clone the repo
git clone https://github.com/GemFund/GemFund-App.git
cd GemFund-App

# Install dependencies
flutter pub get

# Setup Supabase & Gemini API keys (in .env or config file)
# Example: SUPABASE_URL=... SUPABASE_ANON_KEY=... GEMINI_API_KEY=...

# Run on Chrome (web)
flutter run -d chrome

# Or on device/emulator
flutter run
