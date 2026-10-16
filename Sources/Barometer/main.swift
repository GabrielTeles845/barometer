// O executável só dá a partida; tudo mora na BarometerKit, onde os testes alcançam.

import BarometerKit

MainActor.assumeIsolated { Inicio.rodar() }
