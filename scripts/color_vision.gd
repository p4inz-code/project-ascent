class_name ColorVision
extends RefCounted
## Colour-vision correction for the world view (red-weak, green-weak, blue-weak). The standard
## daltonize recipe: simulate how the colour looks to that eye (Machado et al. matrices), take
## what was lost, and shift it into the channels that eye does see. The result is one 3x3
## matrix the post-process shader multiplies every pixel by; grey stays exactly grey.

enum Kind { OFF, PROTAN, DEUTAN, TRITAN }

const NAMES: Array[String] = ["OFF", "RED-WEAK", "GREEN-WEAK", "BLUE-WEAK"]

# Simulation of each deficiency (Machado, Oliveira, Fernandes 2009, severity 1.0), row-major.
const SIM_PROTAN := [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
const SIM_DEUTAN := [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]
const SIM_TRITAN := [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]
# Where the lost difference goes.
const SHIFT_RG := [[0.0, 0.0, 0.0], [0.7, 1.0, 0.0], [0.7, 0.0, 1.0]]
const SHIFT_B := [[1.0, 0.0, 0.7], [0.0, 1.0, 0.7], [0.0, 0.0, 0.0]]
const IDENTITY := [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]


## Row-major 3x3 correction for a kind: I + Shift * (I - Sim).
static func rows(kind: int) -> Array:
	var sim: Array
	var shift: Array
	match kind:
		Kind.PROTAN:
			sim = SIM_PROTAN
			shift = SHIFT_RG
		Kind.DEUTAN:
			sim = SIM_DEUTAN
			shift = SHIFT_RG
		Kind.TRITAN:
			sim = SIM_TRITAN
			shift = SHIFT_B
		_:
			return IDENTITY.duplicate(true)
	var err: Array = []
	for r in 3:
		var row: Array = []
		for c in 3:
			row.append(float(IDENTITY[r][c]) - float(sim[r][c]))
		err.append(row)
	var out: Array = []
	for r in 3:
		var row2: Array = []
		for c in 3:
			var v := float(IDENTITY[r][c])
			for k in 3:
				v += float(shift[r][k]) * float(err[k][c])
			row2.append(v)
		out.append(row2)
	return out


## The same matrix as a Basis (columns), ready for a mat3 shader uniform.
static func matrix(kind: int) -> Basis:
	var m := rows(kind)
	return Basis(
		Vector3(m[0][0], m[1][0], m[2][0]),
		Vector3(m[0][1], m[1][1], m[2][1]),
		Vector3(m[0][2], m[1][2], m[2][2]))
