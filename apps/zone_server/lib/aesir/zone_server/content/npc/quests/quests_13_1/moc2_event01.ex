defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Moc2Event01 do
  @moduledoc """
  The crystal of the Morocc hideout that pulls the player into Rin's last stand against
  Rayan.

  ## Behavior

  - Reveals itself when enabled, hides itself on boot, when disabled and on a click.
  - On touch plays the abduction cutscene: the player is blinded, Rin, Rayan and the Dandelion
    members appear, the fight plays out through effects and announcements, and it ends with Rin
    overpowered: quest 7019 advances to 7020, the NPC hides itself, the remaining gang members
    are hidden and the corpse is enabled and called.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_dan01",
        x: 31,
        y: 27,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#moc2_event01",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "#moc2_event01"
  @map "que_dan01"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: disablenpc(ctx, @npc)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
  def on_event("OnTouch_", ctx), do: crystal_cutscene(ctx)

  defp crystal_cutscene(ctx) do
    ctx = struck_blind(ctx)
    ctx = rin_arrives(ctx)
    rin_overpowered(ctx)
  end

  defp struck_blind(ctx) do
    ctx =
      ctx
      |> soundeffect("wander_man_move.wav", 1)
      |> sc_start(:sc_blind, 600_000, 0)
      |> mes("As soon as you touched the crystal,")
      |> mes("you feel your body being pulled into the space gap.")
      |> mes("You remember Kidd's confused voice, screaming your name.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("By the way, where am I?")
      |> mes("Argh.. My head hurts...")
      |> mapannounce(
        @map,
        "Female Voice: Checkmate! You can't run away any longer!",
        1,
        "0x7b68ee"
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(".. ? Wh... What's going on?")
      |> mes("I can't see things.. I'm getting dizzy...")
      |> mes("What just happened?")
      |> mapannounce(
        @map,
        "Male Voice: *Giggle Giggle* If you thought I was alone, you're mistaken! Argh!",
        1,
        "0xA8A8A8"
      )
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Huh? Are they fighting?")
    |> mes("I can hear a crowd of people coming...")
    |> mes("Argh! It's too dark to see...!")
    |> donpcevent("Rin#moc2_bt_rin01::OnEnable")
    |> donpcevent("Rayan#moc2_bt_r01::OnEnable")
    |> donpcevent("Dandelion Member#moc2_1::OnEnable")
    |> donpcevent("Dandelion Member#moc2_2::OnEnable")
    |> next()
    |> mes("[Familiar Female Voice]")
    |> mes("Shut up! It's creepy that you all look alike. Bring it on! I'm not afraid of you!")
    |> mes("I'm not going to let you run away again!")
    |> next()
    |> soundeffect("wander_man_move.wav", 1)
    |> sc_end(:sc_blind)
  end

  defp rin_arrives(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("... !!!!")
      |> mes("Rin!!!!")
      |> mes("Why? Why is Rin here? Wait, where am I?")
      |> mes("Argh.. I can't move at all...")
      |> next()
      |> specialeffect(:beginspell2, :area, "Dandelion Member#moc2_1")
      |> specialeffect(:beginspell2, :area, "Dandelion Member#moc2_2")

    ctx = emotion(ctx, :surprise, getnpcid(ctx, "Rin#moc2_bt_rin01"))

    ctx
    |> emotion(:surprise, playerattached(ctx))
    |> mes("[Rin]")
    |> mes("You're not alone. So what?")
    |> mes("You're still coming with me!")
    |> next()
    |> donpcevent("Rin#moc2_bt_rin01::OnDisable")
    |> donpcevent("Rin#moc2_bt_rin02::OnEnable")
    |> specialeffect(:icecrash, :area, "Rin#moc2_bt_rin01")
    |> specialeffect(:meteorstorm, :area, "Rin#moc2_bt_rin01")
    |> mes("[Rayan]")
    |> mes("Hah, how impressive! You run like a rabbit!")
    |> mes("I should have you killed you when I had the chance.")
    |> mes("I didn't expect you to be so persistent...")
    |> next()
    |> mes("[Rin]")
    |> mes("That's what I wanted to say!")
    |> mes("You played me like a chess piece,")
    |> mes(
      "and now I want to tear you apart in five pieces. Why don't you just shut up and surrender before I kill you?"
    )
    |> next()
    |> mes("[Rayan]")
    |> mes("Hah.. You still have no idea, huh? You already lost this game, lady.")
    |> donpcevent("Dandelion Member#moc2_3::OnEnable")
    |> donpcevent("Dandelion Member#moc2_4::OnEnable")
    |> donpcevent("Dandelion Member#moc2_5::OnEnable")
    |> next()
    |> specialeffect(:freezed, :area, "Rin#moc2_bt_rin02")
    |> emotion(:surprise)
    |> mapannounce(@map, "Rin: When.. When did you...!?!", 1, "0x7b68ee")
    |> mes("[Rayan]")
    |> mes("I'm sorry that I have to do this.")
    |> mes("...")
    |> mes("Kill her.")
    |> specialeffect(:beginspell2, :area, "Dandelion Member#moc2_3")
    |> specialeffect(:beginspell2, :area, "Dandelion Member#moc2_4")
    |> specialeffect(:beginspell2, :area, "Dandelion Member#moc2_5")
    |> next()
    |> mapannounce(
      @map,
      "Rayan: Follow me as soon as you take care of her. Our next meeting place is the usual place. I'm leaving.",
      1,
      "0xA8A8A8"
    )
    |> donpcevent("Rayan#moc2_bt_r01::OnDisable")
    |> donpcevent("Dandelion Member#moc2_1::OnDisable")
    |> donpcevent("Dandelion Member#moc2_2::OnDisable")
  end

  defp rin_overpowered(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Rin-!!!")
    |> specialeffect(:lightbolt, :area, "Rin#moc2_bt_rin02")
    |> specialeffect(:firepillarbomb, :area, "Rin#moc2_bt_rin02")
    |> specialeffect(:meteorstorm, :area, "Rin#moc2_bt_rin02")
    |> donpcevent("Rin#moc2_bt_rin02::OnDisable")
    |> next()
    |> mes("You feel helpless: you can do nothing but watch her slowly get overpowered..")
    |> mes("Then, the pressure on your body suddenly dissipates.")
    |> changequest(7019, 7020)
    |> close()
    |> disablenpc(@npc)
    |> donpcevent("Dandelion Member#moc2_3::OnDisable")
    |> donpcevent("Dandelion Member#moc2_4::OnDisable")
    |> donpcevent("Dandelion Member#moc2_5::OnDisable")
    |> donpcevent("Corpse#moc2_dead01::OnEnable")
    |> donpcevent("Corpse#moc2_dead01::OnCall")
  end
end
