# Pin npm packages by running ./bin/importmap

pin 'application'
pin 'keyboard', to: 'keyboard.js'

pin_all_from 'app/javascript/components', under: 'components'
