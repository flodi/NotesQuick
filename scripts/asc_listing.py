#!/usr/bin/env python3
"""Fills in the NotesQuick App Store listing from Store/listing.json, through the App Store Connect API.
One app record, two platforms (iOS and macOS): every step is applied to both versions.

  asc_listing.py metadata        texts, categories, version, copyright, content rights, review details
  asc_listing.py agerating       age rating (everything "no" -> 4+)
  asc_listing.py pricing         free, all countries
  asc_listing.py screenshots     version screenshots for every language and device
  asc_listing.py submit <build>  attaches the build and sends both versions to review
  asc_listing.py status          summary of what is missing

Idempotent: it can be run again, it updates instead of duplicating.
Not covered (no API): the privacy questionnaire ("nutrition label"), to be done on the website.

Environment: ASC_API_ISSUER (required); ASC_REVIEW_PHONE (required by `metadata`: the review contact
phone number stays out of this public repository).
"""
import hashlib, json, os, sys, urllib.request

sys.path.insert(0, os.path.dirname(__file__))
import asc

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = json.load(open(os.path.join(ROOT, "Store/listing.json")))
APP = L["app"]["appId"]
PLATFORMS = ("IOS", "MAC_OS")
EDITABLE = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")
_, TOKEN = asc.find_key()


def api(method, path, body=None, ok=(200, 201, 204)):
    st, d = asc.api(TOKEN, method, path, body)
    if st not in ok:
        raise SystemExit(f"{method} {path} -> {st}\n{d}")
    return d


def version(platform):
    for v in api("GET", f"/v1/apps/{APP}/appStoreVersions?filter[platform]={platform}")["data"]:
        if v["attributes"]["appStoreState"] in EDITABLE:
            return v
    raise SystemExit(f"No editable {platform} version.")


def app_info():
    for info in api("GET", f"/v1/apps/{APP}/appInfos")["data"]:
        if info["attributes"].get("state") not in ("READY_FOR_DISTRIBUTION", "REPLACED_WITH_NEW_INFO"):
            return info
    raise SystemExit("No editable appInfo.")


def upsert_localization(kind, parent_rel, parent_type, parent_id, locale, attrs):
    """kind: appInfoLocalizations | appStoreVersionLocalizations."""
    existing = api("GET", f"/v1/{parent_rel}/{parent_id}/{kind}")["data"]
    loc = next((x for x in existing if x["attributes"]["locale"] == locale), None)
    if loc:
        api("PATCH", f"/v1/{kind}/{loc['id']}", {"data": {"type": kind, "id": loc["id"], "attributes": attrs}})
        return loc["id"]
    rel_name = "appInfo" if kind == "appInfoLocalizations" else "appStoreVersion"
    created = api("POST", f"/v1/{kind}", {"data": {
        "type": kind, "attributes": {"locale": locale, **attrs},
        "relationships": {rel_name: {"data": {"type": parent_type, "id": parent_id}}}}})
    return created["data"]["id"]


def metadata():
    a = L["app"]
    phone = os.environ.get("ASC_REVIEW_PHONE") or sys.exit("Set ASC_REVIEW_PHONE (review contact phone number).")
    info = app_info()
    api("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": a["primaryCategory"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": a["secondaryCategory"]}}}}})
    print("categories ok")
    for locale, t in L["locales"].items():
        upsert_localization("appInfoLocalizations", "appInfos", "appInfos", info["id"], locale, {
            "name": t["name"], "subtitle": t["subtitle"], "privacyPolicyUrl": t.get("privacyPolicyUrl", a["privacyPolicyUrl"])})
    api("PATCH", f"/v1/apps/{APP}", {"data": {"type": "apps", "id": APP, "attributes": {
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    print("app info and content rights ok")

    review = {**L["review"], "contactPhone": phone}
    for platform in PLATFORMS:
        v = version(platform)
        api("PATCH", f"/v1/appStoreVersions/{v['id']}", {"data": {"type": "appStoreVersions", "id": v["id"], "attributes": {
            "versionString": a["version"], "copyright": a["copyright"]}}})
        for locale, t in L["locales"].items():
            upsert_localization("appStoreVersionLocalizations", "appStoreVersions", "appStoreVersions", v["id"], locale, {
                "description": t["description"], "keywords": t["keywords"], "promotionalText": t["promotionalText"],
                "supportUrl": t.get("supportUrl", a["supportUrl"])})
        detail = api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail", ok=(200, 404))
        if isinstance(detail, dict) and detail.get("data"):
            rid = detail["data"]["id"]
            api("PATCH", f"/v1/appStoreReviewDetails/{rid}", {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": review}})
        else:
            api("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": review,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}})
        print(platform, "version", a["version"], "texts and review details ok")


def agerating():
    """Every answer is negative: a notes app with no web access and no shared content. Result 4+."""
    info = app_info()
    attrs = {k: "NONE" for k in (
        "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
        "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity",
        "sexualContentOrNudity", "horrorOrFearThemes", "matureOrSuggestiveThemes", "violenceCartoonOrFantasy",
        "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic")}
    attrs.update({k: False for k in (
        "advertising", "gambling", "healthOrWellnessTopics", "lootBox", "messagingAndChat", "parentalControls",
        "ageAssurance", "socialMedia", "socialMediaAgeRestricted", "unrestrictedWebAccess", "userGeneratedContent")})
    api("PATCH", f"/v1/ageRatingDeclarations/{info['id']}",
        {"data": {"type": "ageRatingDeclarations", "id": info["id"], "attributes": attrs}})
    rating = api("GET", f"/v1/appInfos/{info['id']}?fields[appInfos]=appStoreAgeRating")["data"]["attributes"]
    print("age rating:", rating["appStoreAgeRating"])


def pricing():
    """Free (price 0 with Italy as base country) and available in every country, future ones included."""
    free = next(p for p in api("GET", f"/v1/apps/{APP}/appPricePoints?filter[territory]=ITA&limit=200")["data"]
                if float(p["attributes"]["customerPrice"]) == 0)
    api("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": APP}},
            "baseTerritory": {"data": {"type": "territories", "id": "ITA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    print("price: free")

    # Price and availability are separate: without availability an approved app stays invisible in every store.
    existing = api("GET", f"/v1/apps/{APP}/appAvailabilityV2", ok=(200, 404))
    if isinstance(existing, dict) and existing.get("data"):
        print("availability already set")
        return
    territories = [t["id"] for t in api("GET", "/v1/territories?limit=200")["data"]]
    api("POST", "/v2/appAvailabilities", {
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True}, "relationships": {
            "app": {"data": {"type": "apps", "id": APP}},
            "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in territories]}}},
        "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}", "attributes": {"available": True},
                      "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in territories]})
    print("availability:", len(territories), "countries")


def upload_asset(kind, rel_name, rel_type, rel_id, path):
    """Asset reservation -> chunked upload -> commit with MD5."""
    data = open(os.path.join(ROOT, path), "rb").read()
    created = api("POST", f"/v1/{kind}", {"data": {
        "type": kind, "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {rel_name: {"data": {"type": rel_type, "id": rel_id}}}}})["data"]
    for op in created["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(req, timeout=300).read()
    api("PATCH", f"/v1/{kind}/{created['id']}", {"data": {"type": kind, "id": created["id"], "attributes": {
        "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return created["id"]


def screenshots():
    for platform in PLATFORMS:
        v = version(platform)
        locs = {x["attributes"]["locale"]: x["id"] for x in
                api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]}
        for locale, by_type in L["screenshots"].items():
            sets = api("GET", f"/v1/appStoreVersionLocalizations/{locs[locale]}/appScreenshotSets")["data"]
            for display_type, files in by_type.items():
                if (display_type == "APP_DESKTOP") != (platform == "MAC_OS"):
                    continue
                current = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == display_type), None)
                if current:
                    # Everything is uploaded again, so the order stays the one in the file.
                    for old in api("GET", f"/v1/appScreenshotSets/{current['id']}/appScreenshots")["data"]:
                        api("DELETE", f"/v1/appScreenshots/{old['id']}")
                    set_id = current["id"]
                else:
                    set_id = api("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                        "attributes": {"screenshotDisplayType": display_type},
                        "relationships": {"appStoreVersionLocalization": {"data": {
                            "type": "appStoreVersionLocalizations", "id": locs[locale]}}}}})["data"]["id"]
                for path in files:
                    upload_asset("appScreenshots", "appScreenshotSet", "appScreenshotSets", set_id, path)
                print("screenshots", platform, locale, display_type, len(files))


def submit(build_number):
    """Attaches the build to both versions and sends each one to review (one submission per platform)."""
    builds = api("GET", f"/v1/builds?filter[app]={APP}&filter[version]={build_number}"
                        "&include=preReleaseVersion&fields[builds]=version,processingState,preReleaseVersion")
    platform_of = {x["id"]: x["attributes"]["platform"] for x in builds.get("included", [])}
    for platform in PLATFORMS:
        build = next((b for b in builds["data"]
                      if platform_of.get(b["relationships"]["preReleaseVersion"]["data"]["id"]) == platform), None)
        if not build or build["attributes"]["processingState"] != "VALID":
            raise SystemExit(f"Build {build_number} for {platform} is not ready.")
        v = version(platform)
        api("PATCH", f"/v1/appStoreVersions/{v['id']}/relationships/build", {"data": {"type": "builds", "id": build["id"]}})
        print(platform, "build", build_number, "attached")
        open_subs = [s for s in api("GET", f"/v1/reviewSubmissions?filter[app]={APP}&filter[state]=READY_FOR_REVIEW"
                                           f"&filter[platform]={platform}")["data"]]
        sub_id = open_subs[0]["id"] if open_subs else api("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": platform},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
        st, r = asc.api(TOKEN, "POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}})
        if st not in (201, 409):
            raise SystemExit(f"{platform}: adding the version to the submission -> {st}\n{r}")
        api("PATCH", f"/v1/reviewSubmissions/{sub_id}", {"data": {"type": "reviewSubmissions", "id": sub_id,
            "attributes": {"submitted": True}}})
        print(platform, "sent to review:", sub_id)


def status():
    info = app_info()
    print("age rating:", info["attributes"].get("appStoreAgeRating"))
    st, d = asc.api(TOKEN, "GET", f"/v1/apps/{APP}/appAvailabilityV2")
    print("availability:", "set" if st == 200 else "MISSING")
    for v in api("GET", f"/v1/apps/{APP}/appStoreVersions")["data"]:
        at = v["attributes"]
        print(at["platform"], at["versionString"], at["appStoreState"])
        for loc in api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]:
            sets = api("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?include=appScreenshots")
            shots = len([x for x in sets.get("included", []) if x["type"] == "appScreenshots"])
            la = loc["attributes"]
            print(f"  {la['locale']}: description {'yes' if la.get('description') else 'NO'}, screenshots {shots}")
        build = api("GET", f"/v1/appStoreVersions/{v['id']}/build", ok=(200, 404))
        print("  build:", (build.get("data") or {}).get("attributes", {}).get("version") if isinstance(build, dict) else None)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "submit":
        submit(sys.argv[2])
        sys.exit()
    steps = {"metadata": metadata, "agerating": agerating, "pricing": pricing, "screenshots": screenshots, "status": status}
    if len(sys.argv) < 2 or sys.argv[1] not in steps:
        sys.exit(__doc__)
    steps[sys.argv[1]]()
