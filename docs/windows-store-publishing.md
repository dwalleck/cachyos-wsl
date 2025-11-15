# Windows Store Publishing Research

Research conducted for cachyos-wsl-x73

## Executive Summary

Publishing to the Microsoft Store requires significant additional work beyond creating a `.wsl` file. However, **as of 2025, there are alternatives** that may be more suitable for community distributions.

### Key Findings

✅ **Good News:**
- Individual developer accounts are now **FREE** (as of June 2025, was $19)
- Company accounts are a one-time **$99 fee** (no renewals)
- Modern alternative: Distribute .wsl files directly (no Store needed)

⚠️ **Challenges:**
- Requires building a **C++ launcher application** (UWP appx package)
- Need Microsoft approval/partnership (contact wslpartners@microsoft.com)
- Identity verification can take **1+ weeks** for company accounts
- Ongoing maintenance burden

## Publishing Options Comparison

### Option 1: Microsoft Store (Traditional UWP Appx)

**What it requires:**
1. C++ launcher application using WSL-DistroLauncher template
2. UWP appx package with embedded tar.gz rootfs
3. Microsoft Store developer account
4. Microsoft WSL team approval
5. Ongoing maintenance for updates

**Pros:**
- Official presence in Microsoft Store
- Automatic updates for users
- Appears in `wsl --list --online` by default
- Professional/official appearance

**Cons:**
- Requires C++ development (separate from our build)
- Complex packaging (appx instead of simple .wsl)
- 1-week+ approval process
- Ongoing Store submission for updates
- Must work with Microsoft WSL team

### Option 2: Direct .wsl File Distribution (Modern Approach)

**What it requires:**
1. Just the `.wsl` file we already have
2. Hosting (GitHub Releases, website, etc.)
3. User documentation

**Pros:**
- ✅ We already have this working!
- No Store approval needed
- No C++ launcher needed
- Fast updates (just upload new file)
- Full control over distribution
- Works great for community/enthusiast distributions

**Cons:**
- Not in official `wsl --list --online`
- Users must download file manually
- Less "official" appearance
- Self-hosted update mechanism (or manual)

### Option 3: Hybrid Approach

**What it requires:**
1. Distribute .wsl file directly (primary method)
2. Optional: Pursue Store listing later if demand justifies

**Pros:**
- Start distributing immediately
- Build user base first
- Pursue Store if justified by popularity
- Lower initial effort

**Cons:**
- Two distribution methods to maintain (if we add Store later)

## Technical Requirements for Store Publishing

### 1. Developer Account

**Individual Account:**
- **Cost:** FREE (as of June 2025)
- **Verification:** Email/phone
- **Timeline:** Usually same day
- **Revenue sharing:** 15% for apps (if using Microsoft payments)

**Company Account:**
- **Cost:** $99 USD one-time (no renewals)
- **Verification:** Independent verification service
- **Timeline:** 1-2 weeks
- **Revenue sharing:** Same as individual

**Registration:** https://developer.microsoft.com/en-us/store/register

### 2. WSL-DistroLauncher Application

**Repository:** https://github.com/microsoft/WSL-DistroLauncher

**What it does:**
- C++ launcher that handles WSL registration
- Provides Windows executable for distribution
- Handles installation, configuration, launching
- Required for Store submissions

**Key files to customize:**
- `DistributionInfo.h` - Distribution name, version
- `DistributionInfo.cpp` - Configuration
- `install.tar.gz` - Your rootfs (our cachyos-v3.wsl renamed)
- `Assets/` - Icons and logos
- `DistroLauncher.appxmanifest` - Package manifest

**Build process:**
1. Clone WSL-DistroLauncher
2. Customize with CachyOS info
3. Add our rootfs as `install.tar.gz`
4. Build in Visual Studio (Release mode)
5. Generate appx package

### 3. Package Requirements

**appx package must include:**
- Compiled launcher executable
- install.tar.gz (our rootfs)
- icon.ico (16x16 to 256x256)
- logo.png (for Store listing)
- DistroLauncher.appxmanifest (configured)

**appxmanifest Identity field:**
```xml
<Identity
  Name="YourCompany.CachyOS"
  Publisher="CN=YourPublisherID"
  Version="1.0.0.0" />
```
Must match your Store account credentials.

**Important:** Distribution name in DistributionInfo.h cannot change between versions (uniquely identifies the distro).

### 4. Store Submission Configuration

**Critical setting:**
- ✅ **Uncheck** "allow installation to alternate drives/removable media"
- WSL only supports installation to system drive
- Checking this box will break functionality

### 5. Microsoft WSL Team Partnership

**Required:** Contact wslpartners@microsoft.com

**They will:**
- Review your distribution
- Agree on testing/publishing plan
- Handle required paperwork
- Guide through approval process

**Recommended:** Reach out before building to understand requirements

## Cost Analysis

### Store Publishing Costs

| Item | Cost | Frequency |
|------|------|-----------|
| Individual developer account | FREE | One-time |
| Company developer account | $99 | One-time |
| App certification | FREE | Per submission |
| Hosting (Store) | FREE | Included |
| Revenue share (if applicable) | 15% | Per transaction |

**Total for community/free distro:** $0 (individual) or $99 (company)

**Note:** WSL distributions are free to install, so no revenue sharing applies.

### Direct Distribution Costs

| Item | Cost | Frequency |
|------|------|-----------|
| GitHub Releases hosting | FREE | Ongoing |
| Custom domain (optional) | ~$12/year | Annual |
| CDN/bandwidth (if needed) | Variable | Monthly |

**Total:** $0-12/year

## Legal and Trademark Considerations

### CachyOS Trademark

**Important:** CachyOS is an existing project with its own branding.

**Questions to resolve:**
1. Do we have permission to use "CachyOS" name in Store?
2. Should we brand as "CachyOS for WSL" or something different?
3. Do we need explicit permission from CachyOS team?
4. Should we collaborate with official CachyOS project?

**Recommendation:** Contact CachyOS team before Store submission.

### Licensing

**Our work:** MIT License (build scripts, configs)
**CachyOS packages:** Various open-source licenses
**Store requirements:** Must comply with Store policies

**Action required:** Review Store policy compliance

## Timeline Estimate

### Store Publishing Timeline

| Phase | Duration |
|-------|----------|
| Developer account setup | 1-14 days |
| Build C++ launcher | 2-5 days |
| Package and test | 1-2 days |
| Contact Microsoft WSL team | Ongoing |
| Store submission review | 1-7 days |
| **Total** | **2-4 weeks** |

### Direct Distribution Timeline

| Phase | Duration |
|-------|----------|
| Upload to GitHub Releases | 10 minutes |
| Write user documentation | 1-2 hours |
| Announce availability | Immediate |
| **Total** | **Same day** |

## Update and Maintenance

### Store Updates

**Process:**
1. Build new rootfs
2. Update version in appxmanifest
3. Rebuild appx package
4. Submit to Store for review
5. Wait for certification (1-7 days)
6. Users auto-update (or manual)

**Effort per update:** 4-8 hours + review wait

### Direct Distribution Updates

**Process:**
1. Build new rootfs
2. Upload to GitHub Releases
3. Update documentation
4. Announce update

**Effort per update:** 30 minutes

**User experience:** Manual re-download and install

## Recommendation

### For This Project (Learning Exercise)

**Recommended:** Direct .wsl distribution via GitHub Releases

**Rationale:**
1. ✅ We already have everything needed
2. ✅ Immediate distribution (no approval wait)
3. ✅ Full control over updates
4. ✅ No additional code required (no C++ launcher)
5. ✅ Appropriate for community/enthusiast project
6. ✅ Learning goal already achieved

### If Pursuing Production Distribution

**Phased approach:**
1. **Phase 1 (Now):** Release via GitHub with .wsl file
2. **Phase 2:** Gather user feedback, refine
3. **Phase 3:** Assess demand for Store listing
4. **Phase 4:** If justified, build Store package

**Store makes sense if:**
- High user demand (100+ regular users)
- Official partnership with CachyOS team
- Commitment to ongoing maintenance
- Want "official" presence

## Action Items

### To Distribute Now (Recommended)

- [x] Build .wsl file (already done!)
- [ ] Create GitHub Release with .wsl file
- [ ] Write installation instructions for users
- [ ] Add to README.md
- [ ] Optional: Create simple website/landing page

### To Publish to Store (Optional Future)

- [ ] Contact CachyOS team for trademark approval
- [ ] Register developer account ($0-99)
- [ ] Clone and customize WSL-DistroLauncher
- [ ] Build C++ launcher application
- [ ] Package as appx with our rootfs
- [ ] Contact wslpartners@microsoft.com
- [ ] Submit to Store
- [ ] Wait for certification
- [ ] Maintain ongoing updates

## Conclusion

**For a learning project:** Direct distribution is perfect. We have everything we need.

**For production:** Store publishing is a 2-4 week effort that makes sense if this becomes a popular, officially-sanctioned distribution with ongoing maintenance commitment.

**Recommendation:** Ship via GitHub Releases now. Pursue Store only if the project grows and justifies the effort.

## References

- [WSL-DistroLauncher GitHub](https://github.com/microsoft/WSL-DistroLauncher)
- [Store Upload Notes](https://github.com/Microsoft/WSL-DistroLauncher/wiki/Notes-for-uploading-to-the-Store)
- [Microsoft Developer Account Registration](https://developer.microsoft.com/en-us/store/register)
- [WSL Partners Email](mailto:wslpartners@microsoft.com)
- [Free Individual Accounts Announcement](https://blogs.windows.com/windowsdeveloper/2025/09/10/free-developer-registration-for-individual-developers-on-microsoft-store/)
