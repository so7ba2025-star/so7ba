'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"404.html": "d41d8cd98f00b204e9800998ecf8427e",
"assets/AssetManifest.bin": "86e657834314aba031c866c4f7954e79",
"assets/AssetManifest.bin.json": "d1d7d43c52775ba8972aaddf767bd586",
"assets/AssetManifest.json": "279c4fcbbd17a12a7b44d780de5bee1c",
"assets/assets/audio/drag.mp3": "7daf747cdf6690e0e8ec31ea1575e533",
"assets/assets/audio/knock.mp3": "7daf747cdf6690e0e8ec31ea1575e533",
"assets/assets/audio/place.mp3": "7daf747cdf6690e0e8ec31ea1575e533",
"assets/assets/audio/shuffle_d_m.mp3": "0fa07b5200fa8b8239cd9d427e4c0342",
"assets/assets/audio/win.mp3": "b0d1b6545cde78a0e887b4b48118c6f8",
"assets/assets/config/supabase.json": "54d84f63daa86c548317f426de042bdc",
"assets/assets/Domino_tiels/domino_0_0.png": "b5c754266c4da5290e381340f2cd50e2",
"assets/assets/Domino_tiels/domino_0_0_v.png": "39f3637c8679f3233e29898c6c9dd4d0",
"assets/assets/Domino_tiels/domino_0_1.png": "d69a74c835a50316881bf5998d4dfc91",
"assets/assets/Domino_tiels/domino_0_1_v.png": "beafbdd92226e5b7b4995be5f78cdd3f",
"assets/assets/Domino_tiels/domino_0_2.png": "349af092d91427cd348c7a7b3552bb4d",
"assets/assets/Domino_tiels/domino_0_2_v.png": "e5ccc4943ccc2177238d506dc8f6b333",
"assets/assets/Domino_tiels/domino_0_3.png": "544be81744a7b0b88662e2682f091f48",
"assets/assets/Domino_tiels/domino_0_3_v.png": "567a65db570e68d2b0c2ed6fa2c2b36f",
"assets/assets/Domino_tiels/domino_0_4.png": "e687e772c9e1b6c7aa97060916ff73f3",
"assets/assets/Domino_tiels/domino_0_4_v.png": "ac7bfee673de063092010ebd4961e33d",
"assets/assets/Domino_tiels/domino_0_5.png": "85534082992ccc1d069dfad9b9a2bc41",
"assets/assets/Domino_tiels/domino_0_5_v.png": "47b8570ad91f4ff3b8fa71c5b1e01686",
"assets/assets/Domino_tiels/domino_0_6.png": "9cde06186ff7e99d14a178117134d70a",
"assets/assets/Domino_tiels/domino_0_6_v.png": "69fa9c149c3209d6d2268156c787bc34",
"assets/assets/Domino_tiels/domino_1_0.png": "be99f1ab1e2111ce8aad97ac23c90acb",
"assets/assets/Domino_tiels/domino_1_0_v.png": "9f7e16baca64f25a484433ef4b761ca5",
"assets/assets/Domino_tiels/domino_1_1.png": "9cf506b5e424ce6fed0c8df497085658",
"assets/assets/Domino_tiels/domino_1_1_v.png": "3bf68a7f1c0bf9bff15685ac8c2b557e",
"assets/assets/Domino_tiels/domino_1_2.png": "3deeb18e6a45a30d3c12a0b029e56c64",
"assets/assets/Domino_tiels/domino_1_2_v.png": "484ea7c2abe3446062bfcadfa6b948b5",
"assets/assets/Domino_tiels/domino_1_3.png": "815c670d60244e7c2e751f7f006dc9fe",
"assets/assets/Domino_tiels/domino_1_3_v.png": "722fbd28c7cded384e4bb254313d4adc",
"assets/assets/Domino_tiels/domino_1_4.png": "268bd8c3a0d017b13cc4c1906963ec56",
"assets/assets/Domino_tiels/domino_1_4_v.png": "828c15359354301e2dfac1925640f32e",
"assets/assets/Domino_tiels/domino_1_5.png": "b47ae42a6cbd4e8187880b69bd6daceb",
"assets/assets/Domino_tiels/domino_1_5_v.png": "bddebf1016727e69227d555cf25d2abf",
"assets/assets/Domino_tiels/domino_1_6.png": "6cdc30a09163fa50637fe6849b392f64",
"assets/assets/Domino_tiels/domino_1_6_v.png": "9f15aa5425dc01d8fb36dc5c84692497",
"assets/assets/Domino_tiels/domino_2_0.png": "e9f6df96d8e2e83d20e768a224f17d85",
"assets/assets/Domino_tiels/domino_2_0_v.png": "c5e28e5149b852015097698f57224a28",
"assets/assets/Domino_tiels/domino_2_1.png": "f9836d5581030168f780813d46783f10",
"assets/assets/Domino_tiels/domino_2_1_v.png": "5bb11fcfc06db42f9220589ed100a719",
"assets/assets/Domino_tiels/domino_2_2.png": "4d3649bbccdcacb6855b3a2baec9138e",
"assets/assets/Domino_tiels/domino_2_2_v.png": "1a7053f243c367bbbf3c91b94ae78021",
"assets/assets/Domino_tiels/domino_2_3.png": "0c5ee9eea19918fd24a30fa8e4e0c7da",
"assets/assets/Domino_tiels/domino_2_3_v.png": "af39024d02ea8f29a17ee68d40ece900",
"assets/assets/Domino_tiels/domino_2_4.png": "66fbb71d99ae806ccfd5c0e4e1cd0f6f",
"assets/assets/Domino_tiels/domino_2_4_v.png": "948ef1d69aeb4434d3adec47d7aa64c5",
"assets/assets/Domino_tiels/domino_2_5.png": "06c78196443c464c5054205bbf0dfb04",
"assets/assets/Domino_tiels/domino_2_5_v.png": "72df6237ca5332ab6ad7976089320560",
"assets/assets/Domino_tiels/domino_2_6.png": "3df39729c7c6a2024f30100c948558fc",
"assets/assets/Domino_tiels/domino_2_6_v.png": "6236d715dc6bcf128183470bcf1587dc",
"assets/assets/Domino_tiels/domino_3_0.png": "dba35970d8e4b06f7c031744ed691bb5",
"assets/assets/Domino_tiels/domino_3_0_v.png": "22ce2c5870c00d6fda3e979e1930b9a8",
"assets/assets/Domino_tiels/domino_3_1.png": "f97ceea4fafe9ce5b8b45fa22a177e3f",
"assets/assets/Domino_tiels/domino_3_1_v.png": "7b8fdde9a7bdd407bd398409aef4af0d",
"assets/assets/Domino_tiels/domino_3_2.png": "0f37852c91350979928924352fd71c65",
"assets/assets/Domino_tiels/domino_3_2_v.png": "7fcec85a1755f9debebd7db965df6c0e",
"assets/assets/Domino_tiels/domino_3_3.png": "1956bd90f8f6223334e34abf4dcd593f",
"assets/assets/Domino_tiels/domino_3_3_v.png": "11089b3f6f40f54e1332069658637958",
"assets/assets/Domino_tiels/domino_3_4.png": "f07d83270c97d73c6d1fe335e84f6377",
"assets/assets/Domino_tiels/domino_3_4_v.png": "0caba0a743fa01a2be0598bcbc18fba6",
"assets/assets/Domino_tiels/domino_3_5.png": "6746f679cc607488a7b11d800497e3e2",
"assets/assets/Domino_tiels/domino_3_5_v.png": "213e9c002f26af5ad83a21e6a3a3739a",
"assets/assets/Domino_tiels/domino_3_6.png": "0c82c970345d2031f577c86aea407f46",
"assets/assets/Domino_tiels/domino_3_6_v.png": "83df675f371c921587b319bdcc92e37d",
"assets/assets/Domino_tiels/domino_4_0.png": "699a32e4d1407e5ea3a6af59b9c4fb1b",
"assets/assets/Domino_tiels/domino_4_0_v.png": "fb6aba2ad4b38a2485831f806079713e",
"assets/assets/Domino_tiels/domino_4_1.png": "870126de87195e5ca5b9498c10ad034a",
"assets/assets/Domino_tiels/domino_4_1_v.png": "3e9e32b237588e28f3e645568f109b49",
"assets/assets/Domino_tiels/domino_4_2.png": "b09c6b79852e85ca5f03fe9eed8a8179",
"assets/assets/Domino_tiels/domino_4_2_v.png": "18bf48f1bbeef097b1f335ebdc3e31cc",
"assets/assets/Domino_tiels/domino_4_3.png": "7bfbd04edd4c8656d25f4afcbf434274",
"assets/assets/Domino_tiels/domino_4_3_v.png": "a8904d9e0f2642bea30b7379d26745f6",
"assets/assets/Domino_tiels/domino_4_4.png": "12266eedcff0039f7f25df714654abf9",
"assets/assets/Domino_tiels/domino_4_4_v.png": "18b2fae1776aa5da06f63f8d17b175a3",
"assets/assets/Domino_tiels/domino_4_5.png": "510c09318dcbc6db6bd3a020f3f3ca91",
"assets/assets/Domino_tiels/domino_4_5_v.png": "8953c23639cac001225ab851be44b4ce",
"assets/assets/Domino_tiels/domino_4_6.png": "b9f684091869163aab5bc00d087e88fd",
"assets/assets/Domino_tiels/domino_4_6_v.png": "8b63bb94cb1ac3ef4d45a3cfed54d203",
"assets/assets/Domino_tiels/domino_5_0.png": "046ea44754f133aa9c36bc4e840f9946",
"assets/assets/Domino_tiels/domino_5_0_v.png": "3fd09d12fd9743de69b8d15bd70085f1",
"assets/assets/Domino_tiels/domino_5_1.png": "dd56e881eb33fc113d61a4c9146f61a7",
"assets/assets/Domino_tiels/domino_5_1_v.png": "bfed5a86671bda8faf3940f9c032e191",
"assets/assets/Domino_tiels/domino_5_2.png": "5fd11fffe4eec68e9e2a591cba0d4a33",
"assets/assets/Domino_tiels/domino_5_2_v.png": "355e2fef73fd57a64211b829a8eb164c",
"assets/assets/Domino_tiels/domino_5_3.png": "de751c04a5daeec8d310f13641ebbade",
"assets/assets/Domino_tiels/domino_5_3_v.png": "1b88497623c83ba32439dedd7878e011",
"assets/assets/Domino_tiels/domino_5_4.png": "9a2a5ee42a1e5d62419cd1e51de54163",
"assets/assets/Domino_tiels/domino_5_4_v.png": "23ca3d3f37efe789e5d66beb5e0b4af4",
"assets/assets/Domino_tiels/domino_5_5.png": "3a3f8432d2d7a16b0e8212c2ade7c48d",
"assets/assets/Domino_tiels/domino_5_5_v.png": "86e241f8c0f04e710232d4e314c31ff4",
"assets/assets/Domino_tiels/domino_5_6.png": "d9595c796348996853a25b895799d363",
"assets/assets/Domino_tiels/domino_5_6_v.png": "5c19af73d9cb0e46f64a6d700d1a650b",
"assets/assets/Domino_tiels/domino_6_0.png": "7752be9edef425857d26b34aca76601a",
"assets/assets/Domino_tiels/domino_6_0_v.png": "4daf60e00c8d1add48638b166f61c551",
"assets/assets/Domino_tiels/domino_6_1.png": "c2ab3be86503e0b460a188e224e5341d",
"assets/assets/Domino_tiels/domino_6_1_v.png": "a0d49cef87bf97813f04c0643e0f4aac",
"assets/assets/Domino_tiels/domino_6_2.png": "b9d0a2f0937ed4723f0f627b8feda9e2",
"assets/assets/Domino_tiels/domino_6_2_v.png": "81a18cf9fac3b9bfee0b55904d297740",
"assets/assets/Domino_tiels/domino_6_3.png": "55047444ed1cb32be9748821ceb7454b",
"assets/assets/Domino_tiels/domino_6_3_v.png": "16d3e32c4b97a309ff49619e985de6bb",
"assets/assets/Domino_tiels/domino_6_4.png": "a95abf2483148777585f22b09d8128c4",
"assets/assets/Domino_tiels/domino_6_4_v.png": "b4017275b7b4e0965090082c3ea305f3",
"assets/assets/Domino_tiels/domino_6_5.png": "e70da8a9b18511c1e9fa3420267dced6",
"assets/assets/Domino_tiels/domino_6_5_v.png": "8cc3494f2dd0a2040c217a8dc1cdf7ff",
"assets/assets/Domino_tiels/domino_6_6.png": "2630c8b70bcfc564b277465d126ae1b6",
"assets/assets/Domino_tiels/domino_6_6_v.png": "8a66cee8fb7db20f50366878ad120594",
"assets/assets/Domino_tiels/domino_back.png": "52c1fd4fed731cc22a79a76fe2b16cbe",
"assets/assets/Domino_tiels/domino_back_ai.png": "52c1fd4fed731cc22a79a76fe2b16cbe",
"assets/assets/Domino_tiels/generate_domino_tiles.py": "a104dfc16bd0b0c17452d0474b8abd1b",
"assets/assets/Icon/5646.png": "e0c37f766ff7c2e9a76c306b5b8c00a2",
"assets/assets/Icon/app_icon.png": "abb075dc4498059cef5471b8480da280",
"assets/assets/Icon/google_logo.png": "94d8a00b46e520820085e1969e2848d7",
"assets/assets/images/555o.png": "6fd2b90f542a4f4b2fdf27818fb97dd6",
"assets/assets/images/Gemini_Generated_Image_ei5rs1ei5rs1ei5r.png": "affb2d1b1328d128767808f214e4fa2f",
"assets/assets/images/logo.png": "07e9de1015afd25198038ee9a9d35cf8",
"assets/assets/images/table_wood.jpg": "84cf4ae868006170324f67d306ed4691",
"assets/assets/sounds/4rnkGCe6LgE.mp3": "5850e287c20a3272e72398e9776eb000",
"assets/assets/sounds/5Select_1st.mp3": "5850e287c20a3272e72398e9776eb000",
"assets/assets/sounds/Applause.mp3": "5476657c130c703bae0e63a46c4e656f",
"assets/assets/sounds/clack.mp3": "5850e287c20a3272e72398e9776eb000",
"assets/assets/sounds/clout.mp3": "b504b2fe427053dc663a14cba61df35d",
"assets/assets/sounds/dom.mp3": "5850e287c20a3272e72398e9776eb000",
"assets/assets/sounds/embulance.mp3": "2ded31cdd6241beb19393b6126c9351e",
"assets/assets/sounds/kiss.mp3": "c956128eb0a4b20ee78e798898e30b75",
"assets/assets/sounds/mixkit-ambulance-siren-us-1642.wav": "183e25400e30321ca07fbbf8fd59b6e2",
"assets/assets/sounds/n1.mp3": "5850e287c20a3272e72398e9776eb000",
"assets/assets/sounds/notification_sound.mp3": "2ded31cdd6241beb19393b6126c9351e",
"assets/assets/sounds/notification_sound.wav": "183e25400e30321ca07fbbf8fd59b6e2",
"assets/assets/sounds/open_d_m.mp3": "7daf747cdf6690e0e8ec31ea1575e533",
"assets/assets/sounds/pass.mp3": "5850e287c20a3272e72398e9776eb000",
"assets/assets/sounds/Select_1st.mp3": "7daf747cdf6690e0e8ec31ea1575e533",
"assets/assets/sounds/shuffle_d_m.mp3": "0fa07b5200fa8b8239cd9d427e4c0342",
"assets/assets/sounds/win.mp3": "b0d1b6545cde78a0e887b4b48118c6f8",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "acc7af8c493c7f3bb2edb9f6ab2d5046",
"assets/NOTICES": "19f98e5ff575bcff6bf97cc022c75cc9",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "51e403515b32d94dd34f3595003a1096",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "56e1a84cee9a4c28f079a95cf41c1647",
"icons/Icon-192.png": "fbd60fa42d934372a0fd6f6991c225e7",
"icons/Icon-512.png": "0937c4a05fa5704f08bda0c0ea0381c9",
"icons/Icon-maskable-192.png": "fbd60fa42d934372a0fd6f6991c225e7",
"icons/Icon-maskable-512.png": "0937c4a05fa5704f08bda0c0ea0381c9",
"index.html": "a082afb4587c4f0e9b735b037a196773",
"/": "a082afb4587c4f0e9b735b037a196773",
"main.dart.js": "d5d50d06da2ca9e3ebca2fee0e4465d4",
"manifest.json": "9ad60adb7f89db71b2bc0855696d58c9",
"splash/img/dark-1x.png": "975c7ad0cfca0c41b30523de1ff3f8c0",
"splash/img/dark-2x.png": "7b61e10dd1bf0526524b382e41c5f297",
"splash/img/dark-3x.png": "05d1e1bfdb47af1e4654e52131bb019a",
"splash/img/dark-4x.png": "3543d5b821619989afada32a85794e8b",
"splash/img/light-1x.png": "975c7ad0cfca0c41b30523de1ff3f8c0",
"splash/img/light-2x.png": "7b61e10dd1bf0526524b382e41c5f297",
"splash/img/light-3x.png": "05d1e1bfdb47af1e4654e52131bb019a",
"splash/img/light-4x.png": "3543d5b821619989afada32a85794e8b",
"version.json": "6a044cd4eeef474b564283168729b0f8"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
