extends RefCounted
const OFFER_CHANCE := 0.20
const IDS := ["grapple", "repulse", "rewind", "vortex", "chrono", "aegis"]
const DATA := {
	"grapple": {"name":"グラップル", "tag":"引き寄せ / 追撃", "description":"照準の敵にチェーンを当て、手元へ引き寄せる。\n到達後1.5秒以内に対象を撃破すると＋2.0秒。", "cooldown":2.5, "color":Color("58e6d0")},
	"repulse": {"name":"リパルス", "tag":"衝撃 / 空中戦", "description":"前方7mの敵を衝撃波で吹き飛ばす。\n足元へ撃つと跳躍し、空中キルを狙える。", "cooldown":6.0, "color":Color("ffb45e")},
	"rewind": {"name":"リワインド", "tag":"突入 / 離脱", "description":"直前3秒の経路を逆にたどり、約0.8秒で帰還。\n残り時間・弾薬・敵の状態は戻らない。", "cooldown":10.0, "color":Color("69baff")},
	"vortex": {"name":"ボルテックス", "tag":"集敵 / 連続撃破", "description":"照準方向へ装置を投げ、着地点で4秒間展開。\n半径7mの敵を引き寄せてまとめる。", "cooldown":10.0, "color":Color("c493ff")},
	"chrono": {"name":"クロノフィールド", "tag":"設置 / 連射強化", "description":"前方に半径6mの強化フィールドを5秒間設置。\n範囲内では自分の連射速度が1.5倍。", "cooldown":12.0, "color":Color("ffd16a")},
	"aegis": {"name":"イージス", "tag":"防御 / 前進", "description":"4秒間、正面にシールドを展開。\n敵弾を防ぎながら射撃可能。側面・背面は無防備。", "cooldown":10.0, "color":Color("75d5ff")}
}
