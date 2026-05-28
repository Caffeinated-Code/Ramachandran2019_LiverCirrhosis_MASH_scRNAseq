# Biology Primer: Liver Fibrosis Cell Compartments

This primer explains why the analysis focuses on three disease compartments: activated stromal/HSC/myofibroblast-like cells, macrophage/monocyte states, and endothelial cells. Together, they capture the core scar niche in cirrhosis: cells that make matrix, cells that sense and shape injury, and cells that remodel the vascular interface.

## Fibrosis And Cirrhosis In One Page

Healthy liver is organized for metabolism, detoxification, bile production, immune surveillance, and blood filtration. Fibrosis begins when repeated injury turns normal repair into persistent wound healing. Extracellular matrix accumulates, liver architecture stiffens, blood flow changes, and inflammatory signals become self-sustaining. Cirrhosis is advanced fibrosis with nodular remodeling and major risk for portal hypertension, decompensation, and liver cancer.

The biology is not driven by one cell type. Fibrosis is a multicellular program involving stromal activation, macrophage remodeling, endothelial dysfunction, hepatocyte injury, ductular reaction, and immune recruitment. This project focuses on the three compartments most directly connected to scar production, scar maintenance, and translational target discovery.

## Why These Three Compartments

| Compartment | Healthy role | Disease role | Why it matters for target discovery |
|---|---|---|---|
| HSC/myofibroblast-like stromal cells | Store vitamin A, maintain matrix, support sinusoidal structure | Activate after injury, produce collagen and matrix-remodeling proteins, become contractile | Best compartment for fibrosis burden markers and stromal perturbation hypotheses |
| Macrophage/monocyte states | Clear debris, survey pathogens, regulate tolerance and repair | Amplify inflammation, remodel matrix, interact with HSCs, sometimes support resolution | Best compartment for immune-state biomarkers and injury or repair mechanisms |
| Endothelial cells | Maintain fenestrated sinusoids, regulate exchange between blood and hepatocytes | Lose normal sinusoidal identity, promote vascular remodeling, immune trafficking, permeability, and scar-associated niches | Best compartment for vascular niche markers and spatial validation |

## HSC, Mesenchymal, And Myofibroblast-Like Cells

In healthy liver, hepatic stellate cells sit in the space of Disse and store retinoids. They help maintain the local extracellular matrix and communicate with hepatocytes and sinusoidal endothelial cells.

In diseased liver, stellate cells and related stromal populations activate into myofibroblast-like states. They increase collagen genes such as `COL1A1` and `COL3A1`, contractile genes such as `ACTA2` and `TAGLN`, and receptor or matrix genes such as `PDGFRA`, `PDGFRB`, `LUM`, and `DCN`. These cells are central to scar deposition and stiffness, so their genes make strong fibrosis burden and pharmacodynamic candidates.

The caveat is subtype resolution. Activated HSCs, portal fibroblasts, pericytes, and myofibroblasts share many collagen and contractile markers. A compact single-cell run can identify a fibrogenic stromal compartment, but finer subtype claims need deeper stromal subclustering, spatial validation, and protein-level confirmation.

## Macrophage And Monocyte States

Healthy liver macrophages include resident Kupffer cells and recruited monocyte-derived populations. They clear debris, respond to microbial products from the portal circulation, and help maintain immune tolerance.

In fibrosis and cirrhosis, macrophages become highly state-dependent. Some states promote inflammation, HSC activation, and matrix remodeling. Others participate in repair and scar resolution. Markers such as `TREM2`, `CD9`, `SPP1`, `GPNMB`, `LST1`, and complement genes can mark injury-associated macrophage programs.

This makes macrophage genes biologically important but translationally tricky. A macrophage marker can signal disease activity without being a safe therapeutic target. Perturbing macrophage pathways can help or harm depending on timing, etiology, and tissue context.

## Endothelial Cells

Healthy liver sinusoidal endothelial cells are specialized, fenestrated cells that allow exchange between blood and hepatocytes. They regulate vascular tone, immune cell entry, and local signals that help keep stellate cells quiescent.

In chronic injury, endothelial cells remodel. Sinusoidal capillarization, vascular leak, angiogenesis, chemokine presentation, and scar-associated endothelial states become prominent. Markers such as `ACKR1`, `PLVAP`, `VWF`, `PECAM1`, `KDR`, `RAMP2`, and `ENG` help identify vascular remodeling.

Endothelial candidates are useful for spatial readouts and scar-niche mapping. They need safety caution as drug targets because vascular biology is systemic and essential.

## How This Maps To The Analysis

The workflow uses marker programs from these compartments to assign broad disease-relevant labels, then checks those labels against the published Ramachandran annotation layer. The labels are deliberately conservative. They are strong enough to support disease-compartment analysis, but they do not claim perfect subtype resolution.

The three-compartment design also keeps the translational interpretation honest:

- Stromal/HSC signals answer: where is scar production strongest?
- Macrophage signals answer: which immune injury or repair states track disease?
- Endothelial signals answer: how is the vascular scar niche remodeled?

Together, these compartments explain why the strongest fibrosis markers are often excellent biomarkers but not automatically safe drug targets.
