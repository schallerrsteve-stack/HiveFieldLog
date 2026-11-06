# FieldLog – offline borehole logging

## Install for field use (works with no signal)
1. Upload this whole folder to any static HTTPS host, such as GitHub Pages, Netlify, Cloudflare Pages or your company's web server.
2. On each phone or tablet, open the address once while you have signal.
3. Add the app to the home screen. On iPhone/iPad use Safari, then Share, then "Add to Home Screen". On Android use Chrome, then the menu, then "Install app".
4. After that, the app opens and works without signal. Data is stored on the device.

## Daily workflow
- **Field:** In Settings, set your name. Then create or import the project and log your holes. At the end of the day, open the project and tap **Export for office (.json)**, then email or upload the file.
- **Office:** Open FieldLog on a PC and tap **Import / merge file**. You can select every logger's .json file at once. The app merges holes by their internal ID and keeps the newest edit of each hole. A deleted hole stays deleted.
- **Outputs:** On the project page, tap **All logs (PDF)** or **Excel workbook**. For a single hole, open its **Log** tab.

Tip: The office can create the project first and send its .json to the field crews. If crews create the project themselves, files still merge, provided the project numbers match.

## Office use (desktop)
Open the same address in Chrome or Edge on a PC. On screens wider than about 1000 px the app switches to the office layout:
- **Project table:** every hole with its field status, review status, depth, elevation and who logged it.
- **Hole editing:** strata, samples and water appear as editable tables, with the PDF log preview beside them that updates as you type. Enter moves down a column. Typing in a description replaces the field builder text for that layer.
- **Review:** set each hole to Draft, Checked or Final on its Info tab. **Final** locks the hole on every device until someone reopens it. The edit history shows who changed what.
- **Wells:** monitoring wells (or any hole with "+ Add well construction") have a Well tab for stick-up, screen, sand pack and seal. The well is drawn on the log and on the fence diagram.
- **Fence diagram:** a cross-section through the holes you choose and order. It uses distances from the hole coordinates and elevations from ground elevation, and correlates layer groups between holes. Download as an 11 × 17 or Letter PDF.
- **Site plan:** hole locations plotted from GPS or easting/northing, with a north arrow, scale bar, the fence section line and, optionally, groundwater contours and flow direction. Download as PDF.

## Water levels and groundwater
- **On the logs:** the header shows two water levels. **Water (ATD)** is the latest reading taken at the time of drilling (during drilling, seepage or on completion). **Static water level** is the latest "Later reading", with the date and time you entered. Both appear in the default company template header and can be moved or removed under Log layout.
- **Contours and gradient:** the site plan and the 3D model have a **Groundwater** panel. Choose the readings to use: the latest static level per hole, static levels from one monitoring date, or ATD. Each hole needs a ground elevation, and at least 3 wells must not lie in a straight line.
  - **Gradient and flow direction** come from a least-squares best-fit plane through the water elevations (with exactly 3 wells this is the classic three-point solution). The panel shows i (m/m or ft/ft), the flow bearing from grid north, the fit (R²) and each well's residual.
  - **Contours** are triangulated between the wells by default, so they are not drawn outside the area the wells cover. You can also choose the best-fit plane, which draws straight, parallel contours across the whole plan. The interval is automatic unless you enter one.
  - **On the site plan PDF** you get the contours with labels, the groundwater elevation (WL) beside each well, a flow arrow with the gradient, and a summary line. **In 3D** the water surface passes through every reading, with contours and a flow arrow drawn on it.
  - The settings are saved with the project and sync to other devices.

## Company template (customization)
Settings → **Company template** sets the standards everyone uses:
- **Pick lists:** main materials, colours, consistency and density terms, moisture, rock types, weathering, strength, methods, sample types, lab tests and soil symbols.
- **Log layout:** title wording, which columns print and their widths, the header fields and their order, the footer note, description text size, the N-chart scale (50/60/100), default depth per page, and colour-filled graphics. A live preview shows page 1 on office screens.
- **Field form:** what must be filled in before a hole can be marked Complete, which fields are hidden on phones, hole ID prefixes and number of digits (e.g. BH26-001), and default sample spacing and length.
- **Graphics:** pattern and colour for each soil symbol. These are used on logs, fence diagrams, the 3D model and the strata list.

With cloud sync, only template admins can change it. List them in the database (see SYNC-SETUP.md); **Save & publish** sends the template to every device, and other users see it read-only. Without sync, the template applies to the device; use **Export / Import template** to copy it to other devices.

## Coordinate systems, QGIS and the 3D model
- **Project coordinate system:** set it when you create or edit a project, for example "MTM NS 2010 zone 5" or "NB Stereographic". Holes with only GPS get easting/northing in that system automatically. Site plans, exports and QGIS layers all use it.
- **QGIS:** use the **GIS / QGIS (GeoJSON)** export, or the live database layers. See QGIS-SETUP.md.
- **3D model:** open **3D model** on the project page. Define the site area automatically, as length × width with a bearing and centre, or by corner coordinates (also drawn on the site plan). Axes show easting/northing, or distance along and across the site when rotated, plus elevation. It shows holes coloured by lithology, plus fill, natural overburden and bedrock, the groundwater surface, the fence section as a 3D panel, and wells. You can change the vertical exaggeration, save an image, or export a .glb file. Surfaces are interpolated between holes (inverse-distance weighting) and are an interpretation. The 3D engine (fieldlog-3d.js) only loads when the model is opened.

## Aerial imagery under site plans (ArcGIS) – switched off by default
To turn it on, set `"enableArcgis": true` in fieldlog-config.json and add a key, as below.
Site plans can show Esri World Imagery under the holes. This uses your ArcGIS Online account.
1. In ArcGIS Online, go to **Content → New item → Developer credentials → API key credentials**. You need a Creator user type, and an admin may have to grant permission to generate API keys.
2. Give it the privilege **Location services → Basemaps**. Under referrers, restrict it to the web address where FieldLog is hosted. You can also set an expiry date.
3. Copy the access token. Either put it in `fieldlog-config.json` as `"arcgisApiKey"` (so everyone gets it), or paste it into **Settings → Aerial imagery** on each device.
4. On the site plan, tick **Aerial imagery underlay**. The imagery is fetched when you open or print the plan, so this needs an internet connection.

Placement: holes with GPS coordinates are placed directly. For easting/northing, enter the coordinate system on the holes, for example "NAD83(CSRS) UTM 20N" or "MTM zone 5 Nova Scotia". The app reads UTM, Canadian MTM and the Nova Scotia MTM zones 4/5 (4,500,000 / 5,500,000 m false eastings). Where a hole has both GPS and easting/northing, the plan reports how well they agree. Datum shifts (ATS77 vs NAD83) are not applied.

After first use, check your organization's credit or usage page to see how basemap requests are counted.

## Cloud sync (optional)
See SYNC-SETUP.md. Once sync is set up, holes logged on any device show up on every other device automatically, with no file exporting needed.

## AGS4 export
On the project page, tap **AGS4 file** for an AGS 4.1 transfer file (LOCA, HDPH, GEOL, SAMP, ISPT, CORE, WSTG). Imperial projects are converted to metric, as AGS requires.

## Files
- index.html – the whole app (includes the jsPDF library)
- sw.js, manifest.webmanifest, icon-*.png – files that make the app installable and usable offline
- fieldlog-config.json – optional sync server preset (see SYNC-SETUP.md)
- supabase.sql – database setup script for cloud sync
- qgis.sql – optional read-only QGIS layers (see QGIS-SETUP.md)
- fieldlog-3d.js – 3D engine (three.js), loaded only for the 3D model
- THIRD-PARTY-NOTICES.txt – open-source licences
