Locales = {
    ['en'] = {
        ['service_started'] = 'Community service started. Spots to clean: %s',
        ['service_completed'] = 'You have completed your community service.',
        ['task_completed'] = 'Task completed. Remaining spots: %s',
        ['not_in_service'] = 'You are not in community service.',
        ['perform_task'] = 'Perform Task',
        ['performing_task'] = 'Performing task...',
        ['task_cancelled'] = 'Task cancelled.',
        ['invalid_args'] = 'Invalid arguments. Usage: /startservice',
        ['no_permission'] = 'You do not have permission for this action.',
        ['service_given'] = 'Community service given to player ID %s for %s spots',
        ['menu_title'] = 'Start Community Service',
        ['menu_desc'] = 'Assign community service to a player',
        ['input_id'] = 'Player ID',
        ['input_spots'] = 'Number of spots to clean'
    },
    ['fi'] = {
        ['service_started'] = 'Yhdyskuntapalvelu aloitettu. Siivottavia paikkoja: %s',
        ['service_completed'] = 'Olet suorittanut yhdyskuntapalvelusi.',
        ['task_completed'] = 'Tehtävä suoritettu. Jäljellä olevia paikkoja: %s',
        ['not_in_service'] = 'Et ole yhdyskuntapalvelussa.',
        ['perform_task'] = 'Suorita tehtävä',
        ['performing_task'] = 'Suoritetaan tehtävää...',
        ['task_cancelled'] = 'Tehtävä keskeytetty.',
        ['invalid_args'] = 'Virheelliset argumentit. Käyttö: /startservice',
        ['no_permission'] = 'Sinulla ei ole oikeuksia tähän toimintoon.',
        ['service_given'] = 'Yhdyskuntapalvelu annettu pelaajalle ID %s, %s paikkaa',
        ['menu_title'] = 'Aloita Yhdyskuntapalvelu',
        ['menu_desc'] = 'Määrää yhdyskuntapalvelu pelaajalle',
        ['input_id'] = 'Pelaajan ID',
        ['input_spots'] = 'Siivottavien paikkojen määrä'
    }
}

function _U(str, ...)
    if Locales[Config.Locale] and Locales[Config.Locale][str] then
        return string.format(Locales[Config.Locale][str], ...)
    end
    return 'Translation missing: ' .. Config.Locale .. '.' .. str
end