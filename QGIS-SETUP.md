# Connecting QGIS to FieldLog

There are two ways to get FieldLog data into QGIS.

## 1. File export (no setup)
On a project page, tap **GIS / QGIS (GeoJSON)**. Unzip the download and drag the `.geojson` files into QGIS.
- **Layers:** holes, strata, samples, water and the section line.
- **Coordinates:** WGS84 (EPSG:4326), as GeoJSON requires. QGIS reprojects on the fly. Set your QGIS project CRS to the project's system (shown in the README inside the zip).
- **Hole attributes:** each hole carries interpretation values: `rock_elev`, `rock_deeper_than`, `gw_elev`, `fill_thick`, `base_fill_elev`, `max_n`, `refusal_depth`, screen elevations. Use them to label holes or to contour a bedrock surface or water table (Raster → Interpolation).

## 2. Live layers from the sync database (once cloud sync is running)
Every hole synced from the field shows up in QGIS the next time you refresh. No exporting is needed.

**One-time setup (admin):**
1. Open `qgis.sql` and change the password near the bottom (`change-me-to-a-long-password`).
2. In Supabase, go to **SQL Editor → New query**, paste in `qgis.sql` and click **Run**. Run `supabase.sql` first if you haven't already. It's safe to run again.
3. This creates read-only views in a schema called `fieldlog_gis`, plus a login `fieldlog_qgis` that can only read those views. The app's public key cannot see them.

**In QGIS:**
1. In the **Browser** panel, right-click **PostgreSQL → New Connection**.
2. Enter the Host, Port and Database from Supabase's **Connect** button. If your office network doesn't support IPv6, use the **Session pooler** details.
3. Under Authentication, enter the user `fieldlog_qgis` (through the pooler it's `fieldlog_qgis.<your-project-ref>`) and the password you set.
4. Expand **fieldlog_gis** and add `holes`, `strata`, `samples`, `water` and `sections` to the map.
5. To see new field data, right-click a layer and choose **Refresh**, or set the layer's auto-refresh interval in Layer Properties → Rendering.

The layers carry the same fields as the file export. Positions come from GPS, or from easting/northing converted using the project's coordinate system.

## Coordinate systems supported (Atlantic Canada)
- **UTM:** zones 19N–22N (NAD83(CSRS))
- **Nova Scotia MTM 2010:** zones 4 and 5 (EPSG:8082 / 8083)
- **ATS77 MTM Nova Scotia:** zones 4 and 5 (older data)
- **MTM:** zones 1–5 (NAD83(CSRS))
- **New Brunswick Stereographic** (EPSG:2953)
- **PEI Stereographic** (EPSG:2954)

All conversions were checked against PROJ/pyproj to within 1 mm. GPS (WGS84) is treated as NAD83(CSRS); the two differ by about 1–2 m.
