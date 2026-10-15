-- BierKompas: eerste video's voor de video-reel ("Brouwerij Highlights").
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit
-- bestand -> Run. Vereist add_videos.sql en add_video_reel.sql (of
-- setup_alles_in_een.sql). Veilig om opnieuw te draaien: een video die er al
-- staat (zelfde YouTube-ID) wordt overgeslagen.
--
-- Het zijn bestaande, openbare YouTube-video's van de makers zelf (kanaal
-- tussen haakjes). Alleen de link en het ID worden opgeslagen; de app speelt
-- ze af met de officiële YouTube-speler. Alle video's zijn op 14-10-2026
-- gecontroleerd: ze bestaan en de maker staat insluiten toe.
-- Een beheerder kan ze via het admin-paneel (Video's) verwijderen of aanvullen.

insert into public.videos (title, category, video_url, source, external_id, sort_order)
select v.title, v.category, 'https://www.youtube.com/watch?v=' || v.external_id, 'youtube', v.external_id, v.sort_order
from (values
    -- Nederlandstalig
    ('Ambachtelijk bierbrouwen: 5 brouwers aan het woord (RTV Oost)', 'Brouwerij', 'GXPOAQKCqmQ', 1),
    ('Hertog Jan: passie voor het brouwen', 'Brouwerij', 'N3BdbrP26w0', 2),
    ('Het brouwproces van bier (Colruyt)', 'Brouwproces', 'Vo5dypGiFjM', 3),
    ('Cursus bierbrouwen bij Bierbrouwerij Bax (OOG Groningen)', 'Brouwerij', 'fF6mM-GBkhA', 4),
    ('Leren bier brouwen (Brouwland)', 'Thuisbrouwen', 'vGz6SPjuGNs', 5),
    ('Märzen-recept 1841 van Brouwerij Bierverbond (Brouwbeesten)', 'Thuisbrouwen', 'gAnHm6NKxpA', 6),
    ('Zelf bier brouwen met een starterspakket (Brouwbroeders)', 'Thuisbrouwen', 'yw92oCh416k', 7),
    -- Engelstalig
    ('How Beer Is Made: inside a real brewery (The Whisky Baron)', 'Brouwproces', 'KqdJtq8siH0', 8),
    ('Beer brewing process in 3D-animatie (Explanation Avenue)', 'Brouwproces', 'ZL_HGOgy_Zo', 9),
    ('Inside Tree House Brewing: brewhouse tour', 'Brouwerij', 'lyNzhHDcIqc', 10),
    ('BrewDog: brewery video tour', 'Brouwerij', '_B-FdT9nQRM', 11),
    ('How craft beer is made: Shipyard Brewing Co.', 'Brouwerij', 'd89OxwY1GUg', 12),
    ('Brewing process: the Brewery at the CIA', 'Brouwproces', 'ceXUKLlEZ-Y', 13),
    ('Inside a 7 BBL commercial brewery (Genus Brewing)', 'Brouwerij', 'JUv6lEUSUEw', 14)
) as v(title, category, external_id, sort_order)
where not exists (
    select 1 from public.videos x where x.source = 'youtube' and x.external_id = v.external_id
);
