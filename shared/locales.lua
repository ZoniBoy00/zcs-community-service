Locales = {}

Locales['en'] = {
  -- Service status messages
  ['service_started'] = 'You have been assigned %s community service tasks',
  ['service_completed'] = 'You have completed your community service',
  ['task_completed'] = 'Task completed. Remaining: %s',
  ['remaining_tasks'] = 'Community Service: %s tasks remaining',
  ['service_extended'] = 'Your community service has been extended by %s tasks',
  
  -- Task messages
  ['new_task'] = 'New task: %s',
  ['new_task_assigned'] = 'A new cleaning spot has been assigned',
  ['cleaning_interrupted'] = 'Task interrupted',
  ['cleaning_progress'] = 'Cleaning...',
  ['cleaning_spot'] = 'Cleaning Spot',
  ['clean_area'] = 'Clean Area',
  ['too_far_from_task'] = 'You need to be closer to the task location',
  
  -- Inventory messages
  ['belongings_returned'] = 'Your belongings have been returned to you',
  ['no_belongings'] = 'You have no stored belongings',
  ['not_in_service'] = 'You cannot retrieve belongings while in community service',
  ['retrieval_point'] = 'Belongings Retrieval',
  
  -- Area restriction messages
  ['leaving_area_warning'] = 'You cannot leave the community service area!',
  
  -- Task type specific translations
  ['task_sweeping'] = 'sweep the area',
  ['task_weeding'] = 'remove weeds',
  ['task_scrubbing'] = 'scrub the surface',
  ['task_pickingtrash'] = 'collect trash',
  
  -- Police messages
  ['player_not_found'] = 'Player not found',
  ['no_permission'] = 'You do not have permission to use this command',
  ['specify_player'] = 'Please specify a player ID',
  ['specify_valid_count'] = 'Please specify a valid number of tasks',
  ['player_not_in_service'] = 'This player is not in community service',
  ['player_status'] = '%s has %s tasks remaining',
  ['player_sent'] = 'Player sent to community service with %s tasks',
  ['player_released'] = 'Player released from community service',
  ['added_tasks'] = 'Added %s tasks to player\'s community service',
  
  -- Menu items
  ['menu_title'] = 'Community Service Management',
  ['menu_assign'] = 'Assign Community Service',
  ['menu_check_status'] = 'Check Player Status',
  ['menu_release'] = 'Release from Service',
  ['menu_add_tasks'] = 'Add More Tasks',
  ['menu_close'] = 'Close Menu',
  ['menu_player_id'] = 'Player ID: %s',
  ['menu_task_count'] = 'Task Count: %s',
  ['menu_select_player'] = 'Select Player',
  ['menu_enter_tasks'] = 'Enter Number of Tasks',
  ['menu_confirm'] = 'Confirm',
  ['menu_cancel'] = 'Cancel',
  ['menu_online_players'] = 'Online Players',
  ['menu_player_format'] = '[%s] %s',
  ['menu_self_service'] = 'Self-Service (Testing)',
  ['menu_back'] = 'Back to Main Menu',
  
  -- Task labels
  ['label_sweeping'] = 'Clean Area (Sweep)',
  ['label_weeding'] = 'Remove Weeds',
  ['label_scrubbing'] = 'Scrub Surface',
  ['label_pickingtrash'] = 'Collect Trash',
  
  -- Progress labels
  ['progress_sweeping'] = 'Sweeping the area...',
  ['progress_weeding'] = 'Removing weeds...',
  ['progress_scrubbing'] = 'Scrubbing the surface...',
  ['progress_pickingtrash'] = 'Collecting trash...',

  -- Add new locale entries for the combat and inventory restrictions
  ['combat_disabled'] = 'You cannot fight while in community service',
  ['inventory_disabled'] = 'You cannot access your inventory while cleaning',
}

Locales['fi'] = {
  -- Service status messages
  ['service_started'] = 'Sinulle on määrätty %s yhdyskuntapalvelutehtävää',
  ['service_completed'] = 'Olet suorittanut yhdyskuntapalvelusi',
  ['task_completed'] = 'Tehtävä suoritettu. Jäljellä: %s',
  ['remaining_tasks'] = 'Yhdyskuntapalvelu: %s tehtävää jäljellä',
  ['service_extended'] = 'Yhdyskuntapalveluasi on pidennetty %s tehtävällä',
  
  -- Task messages
  ['new_task'] = 'Uusi tehtävä: %s',
  ['new_task_assigned'] = 'Uusi siivoustehtävä on määrätty',
  ['cleaning_interrupted'] = 'Tehtävä keskeytyi',
  ['cleaning_progress'] = 'Siivotaan...',
  ['cleaning_spot'] = 'Siivoustehtävä',
  ['clean_area'] = 'Siivoa Alue',
  ['too_far_from_task'] = 'Sinun täytyy olla lähempänä tehtäväpaikkaa',
  
  -- Inventory messages
  ['belongings_returned'] = 'Tavarasi on palautettu sinulle',
  ['no_belongings'] = 'Sinulla ei ole tallennettuja tavaroita',
  ['not_in_service'] = 'Et voi noutaa tavaroitasi yhdyskuntapalvelun aikana',
  ['retrieval_point'] = 'Tavaroiden Nouto',
  
  -- Area restriction messages
  ['leaving_area_warning'] = 'Et voi poistua yhdyskuntapalvelualueelta!',
  
  -- Task type specific translations
  ['task_sweeping'] = 'lakaista alue',
  ['task_weeding'] = 'poistaa rikkaruohot',
  ['task_scrubbing'] = 'hangata pintaa',
  ['task_pickingtrash'] = 'kerätä roskia',
  
  -- Police messages
  ['player_not_found'] = 'Pelaajaa ei löydy',
  ['no_permission'] = 'Sinulla ei ole oikeuksia käyttää tätä komentoa',
  ['specify_player'] = 'Määritä pelaajan ID',
  ['specify_valid_count'] = 'Määritä kelvollinen tehtävien määrä',
  ['player_not_in_service'] = 'Tämä pelaaja ei ole yhdyskuntapalvelussa',
  ['player_status'] = '%s:lla on %s tehtävää jäljellä',
  ['player_sent'] = 'Pelaaja lähetetty yhdyskuntapalveluun %s tehtävällä',
  ['player_released'] = 'Pelaaja vapautettu yhdyskuntapalvelusta',
  ['added_tasks'] = 'Lisätty %s tehtävää pelaajan yhdyskuntapalveluun',
  
  -- Menu items
  ['menu_title'] = 'Yhdyskuntapalvelun Hallinta',
  ['menu_assign'] = 'Määrää Yhdyskuntapalvelu',
  ['menu_check_status'] = 'Tarkista Pelaajan Tila',
  ['menu_release'] = 'Vapauta Palvelusta',
  ['menu_add_tasks'] = 'Lisää Tehtäviä',
  ['menu_close'] = 'Sulje Valikko',
  ['menu_player_id'] = 'Pelaajan ID: %s',
  ['menu_task_count'] = 'Tehtävien Määrä: %s',
  ['menu_select_player'] = 'Valitse Pelaaja',
  ['menu_enter_tasks'] = 'Syötä Tehtävien Määrä',
  ['menu_confirm'] = 'Vahvista',
  ['menu_cancel'] = 'Peruuta',
  ['menu_online_players'] = 'Online Pelaajat',
  ['menu_player_format'] = '[%s] %s',
  ['menu_self_service'] = 'Itsepalvelu (Testaus)',
  ['menu_back'] = 'Takaisin Päävalikkoon',
  
  -- Task labels
  ['label_sweeping'] = 'Siivoa Alue (Lakaise)',
  ['label_weeding'] = 'Poista Rikkaruohot',
  ['label_scrubbing'] = 'Hankaa Pintaa',
  ['label_pickingtrash'] = 'Kerää Roskia',
  
  -- Progress labels
  ['progress_sweeping'] = 'Lakaistaan aluetta...',
  ['progress_weeding'] = 'Poistetaan rikkaruohoja...',
  ['progress_scrubbing'] = 'Hangataan pintaa...',
  ['progress_pickingtrash'] = 'Kerätään roskia...',

  -- Add the same entries for Finnish
  ['combat_disabled'] = 'Et voi taistella yhdyskuntapalvelun aikana',
  ['inventory_disabled'] = 'Et voi käyttää tavaraluetteloasi siivouksen aikana',
}

