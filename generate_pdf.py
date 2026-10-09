from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

c = canvas.Canvas("grafico_patrimonio.pdf", pagesize=letter)
c.drawString(100, 750, "Diagramma di Calcolo del Patrimonio Netto")
c.drawString(100, 730, "-----------------------------------------")
c.drawString(100, 700, "FATTURE IN / SPESE_INCASSI IN -> Entrate (I)")
c.drawString(100, 680, "FATTURE OUT / SPESE_INCASSI OUT -> Uscite (O)")
c.drawString(100, 660, "SCADENZE -> Scadenze Pagate (SP)")
c.drawString(100, 630, "CALCOLO BASE:")
c.drawString(100, 610, "Patrimonio Netto (Net Worth) = (I) - (O) - (SP)")
c.drawString(100, 580, "--")
c.drawString(100, 560, "NOTA: I preventivi non fanno parte del patrimonio netto finche non fatturati.")
c.save()
