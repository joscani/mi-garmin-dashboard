# Base (`master` 9f97476) vs `mejoras-dashboard`

## Qué cambia para quien usa el panel

| Aspecto | Base | Mejorada |
|---|---|---|
| Espacio para gráficos (portátil 1400×900) | Página ajustada a la ventana: KPIs y Jev ocupan ~2/3 y los gráficos quedan en una franja de ~250 px con scroll interno | Scroll natural, 6 KPIs en una sola fila; los gráficos se ven enteros |
| Texto de los ejes | Diminuto (SVG de 10" reescalado) | Legible (7,5"×4,5") |
| Eje de fechas | Etiqueta cada 2 semanas siempre (~26 giradas en un año) | Se adapta al rango (semanas / meses / trimestres) |
| Calidad en Sesiones | **Incorrecta**: nunca da «Mala» (31 sesiones salen como «Regular») | Coincide con el resto (190/190) |
| Modal de detalle | No se reabre al volver a clicar la misma sesión | Se reabre siempre |
| Móvil | Los filtros no se pueden abrir | Se abren con el botón `>` |
| KPIs | Solo el valor | Valor + «↑/↓ vs periodo anterior», coloreado según mejore o empeore |
| Calidad por periodo | 4 líneas de %, saltan entre 0 y 100 | Barras apiladas con el nº de sesiones por calidad |
| Calendario | Fecha 2026-01-01 fija, ignora el filtro | Sigue el filtro; años proporcionales |
| Datos | Solo tabla | Tabla + «Descargar CSV» |
| Colores de calidad | 3 paletas distintas («Regular» amarillo en un sitio, marrón en otro) | Una sola |
| Pestañas | Inactivas en verde, poco contraste | Gris/azul |
| Errores al cargar | La app falla en silencio | Aviso en pantalla |
| Seguridad | PAT en la URL (sale en errores y logs) | PAT en la cabecera |
| Robustez | Aviso de parseo en cada arranque; cadencia perdida; «2:60» posible; TypeError de DT en móvil | Sin avisos ni errores |

## Código

| Métrica | Base | Mejorada |
|---|---|---|
| Líneas R (app.R + R/) | 2169 | 2275 (+106, sobre todo KPIs con delta y descarga) |
| Sitios con los umbrales de calidad | 2 (uno con bug) | 1 (`resumir_calidad`) |
| Formateos de duración copiados | 6 | 1 (`format_duration`) |
| `date_breaks = "2 weeks"` fijos | 4 | 0 (`scale_x_fecha`) |
| Paquetes nuevos | — | 0 |

## Coste / riesgo
- Todo el cambio es en R. No toca Python, datos, Jev ni el despliegue (salvo `.rscignore` + `mejoras/`).
- Riesgo principal: `fillable = FALSE` cambia la sensación del layout (scroll de página en vez de pantalla fija). Se revierte en una línea si no gusta.
- Ver `checks.md` para lo que queda sin verificar.
