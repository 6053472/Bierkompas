-- BierKompas: 21 nieuwe "Artisanal Draught"-badges uit de Stitch-badge-galerij.
-- Uitvoeren via het Supabase-dashboard: SQL Editor -> New query -> plak dit bestand -> Run.
-- Let op: dit voegt alleen de badge-definities toe (zichtbaar als "Vergrendeld" voor iedereen).
-- De progressie-/unlock-logica voor deze requirement_types moet nog gebouwd worden
-- (in tegenstelling tot 'streak', die al automatisch wordt toegekend via record_daily_activity).

alter table public.badges add column if not exists image_asset text;

insert into public.badges (id, title, description, icon_name, image_asset, requirement_type, requirement_value) values
    ('bottle_share', 'Bottle Share', 'Deel een fles met een medebierliefhebber.', 'sports_bar', 'bottle_share', 'social', 1),
    ('better_together', 'Better Together', 'Werk samen met andere bierliefhebbers aan een craft collaboration.', 'sports_bar', 'better_together', 'social', 1),
    ('draft_city', 'Draft City', 'Proef bier van 5 verschillende tapkranen op één locatie.', 'sports_bar', 'draft_city', 'taps', 5),
    ('epic_milestone', 'Epic Milestone', 'Meer dan 5000 check-ins in BierKompas. Legendarische status.', 'military_tech', 'epic_milestone', 'checkins', 5000),
    ('flanders_red_ale', 'Flan-Didly-Anders', 'Proef en waardeer een Vlaams Roodbruin bier.', 'sports_bar', 'flanders_red_ale', 'style', 1),
    ('haze_for_days', 'Haze for Days', 'Word een meester in NEIPA''s (New England IPA).', 'sports_bar', 'haze_for_days', 'style', 1),
    ('home_brewed_goodness', 'Home Brewed Goodness', 'Voor de hobbybrouw-community: gecrafte en gebottelde eigen brouwsels.', 'sports_bar', 'home_brewed_goodness', 'social', 1),
    ('ill_be_bock', 'I''ll Be Bock', 'Proef je eerste Bockbier.', 'sports_bar', 'ill_be_bock', 'style', 1),
    ('keep_your_wits', 'Keep Your Wits About You', 'Word meester in Tarwebier (Witbier).', 'sports_bar', 'keep_your_wits', 'style', 1),
    ('land_of_the_free', 'Land of the Free', 'Proef een Amerikaanse craft beer klassieker.', 'sports_bar', 'land_of_the_free', 'style', 1),
    ('la_creme_de_la_creme', 'La Crème de la Crème', 'Behaal een premium prestatie in BierKompas.', 'military_tech', 'la_creme_de_la_creme', 'milestone', 1),
    ('pucker_up', 'Pucker Up!', 'Proef een zuur bier (Sour).', 'sports_bar', 'pucker_up', 'style', 1),
    ('respect_the_kolsch', 'Respect the Kölsch', 'Eer de traditie en het erfgoed van de Kölsch.', 'sports_bar', 'respect_the_kolsch', 'style', 1),
    ('silence_of_the_lambics', 'Silence of the Lambics', 'Verken de wereld van Lambic en Geuze.', 'sports_bar', 'silence_of_the_lambics', 'style', 1),
    ('super_model', 'Super Model', 'Behaal een hoge gemiddelde beoordeling op je proeverijen.', 'military_tech', 'super_model', 'avg_rating', 1),
    ('taster_please', 'Taster, Please', 'Proef vier verschillende bierstijlen in één sessie.', 'sports_bar', 'taster_please', 'taster_flight', 4),
    ('century_club', 'The Century Club', 'Proef 100 unieke bieren van dezelfde stijl.', 'military_tech', 'century_club', 'style_count', 100),
    ('to_the_alt', 'To the Alt', 'Word meester in Düsseldorf Altbier.', 'sports_bar', 'to_the_alt', 'style', 1),
    ('trip_to_the_farm', 'Trip to the Farm', 'Bezoek een boerderijbrouwerij.', 'local_florist', 'trip_to_the_farm', 'location', 1),
    ('visit_the_beer_garden', 'Visit the Beer Garden', 'Bezoek een Beer Garden.', 'local_florist', 'visit_the_beer_garden', 'location', 1),
    ('wheel_of_styles', 'Wheel of Styles', 'Proef bier uit alle hoofdcategorieën van het Wheel of Styles.', 'military_tech', 'wheel_of_styles', 'style_count', 12)
on conflict (id) do update set
    title = excluded.title,
    description = excluded.description,
    icon_name = excluded.icon_name,
    image_asset = excluded.image_asset,
    requirement_type = excluded.requirement_type,
    requirement_value = excluded.requirement_value;

NOTIFY pgrst, 'reload schema';
