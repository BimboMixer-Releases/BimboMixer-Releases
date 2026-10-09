import matplotlib.pyplot as plt
import networkx as nx

G = nx.DiGraph()

nodes = [
    ("Dashboard", {"pos": (5, 10)}),
    ("Fatture", {"pos": (2, 8)}),
    ("Preventivi", {"pos": (4, 8)}),
    ("Movimenti", {"pos": (6, 8)}),
    ("Scadenze", {"pos": (8, 8)}),
    ("Totale Incassi", {"pos": (3, 5)}),
    ("Totale Spese", {"pos": (5, 5)}),
    ("Scadenze Pagate", {"pos": (7, 5)}),
    ("Patrimonio Netto", {"pos": (5, 2)}),
]

for node, data in nodes:
    G.add_node(node, pos=data["pos"])

edges = [
    ("Dashboard", "Fatture"),
    ("Dashboard", "Preventivi"),
    ("Dashboard", "Movimenti"),
    ("Dashboard", "Scadenze"),
    ("Fatture", "Totale Incassi"),
    ("Movimenti", "Totale Incassi"),
    ("Movimenti", "Totale Spese"),
    ("Scadenze", "Scadenze Pagate"),
    ("Totale Incassi", "Patrimonio Netto"),
    ("Totale Spese", "Patrimonio Netto"),
    ("Scadenze Pagate", "Patrimonio Netto"),
]
G.add_edges_from(edges)

pos = nx.get_node_attributes(G, 'pos')

plt.figure(figsize=(12, 9))
plt.title("Architettura e Calcolo Patrimonio Netto - BimboMixer Contabilita", fontsize=16)

nx.draw(G, pos, with_labels=True, node_size=5000, node_color="#90CAF9", 
        font_size=10, font_weight="bold", arrows=True, arrowsize=20, edge_color="gray")

edge_labels = {
    ("Fatture", "Totale Incassi"): "+",
    ("Movimenti", "Totale Incassi"): "+ (IN)",
    ("Movimenti", "Totale Spese"): "+ (OUT)",
    ("Scadenze", "Scadenze Pagate"): "+ (PAGATA)",
    ("Totale Incassi", "Patrimonio Netto"): "+",
    ("Totale Spese", "Patrimonio Netto"): "-",
    ("Scadenze Pagate", "Patrimonio Netto"): "-",
}

nx.draw_networkx_edge_labels(G, pos, edge_labels=edge_labels, font_color='red', font_size=9)

pdf_path = r'C:\Users\Hp\.gemini\antigravity\brain\5e4bf632-0673-4001-aff3-fc7226eb0d5c\architettura_patrimonio.pdf'
plt.savefig(pdf_path, format='pdf', bbox_inches='tight')
print('PDF saved to: ' + pdf_path)
