defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Lowenone do
  @moduledoc """
  Replays Lowen's confrontation with the Doppelganger.

  ## Behavior

  - Stages the past battle and summons its participants during the vision.
  - Warps the player and dismisses the participants after the scene.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god02",
        x: 174,
        y: 49,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#lowenone",
        trigger: {0, 0}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    ctx
    |> opening()
    |> battle()
    |> aftermath()
  end

  defp opening(ctx) do
    ctx = donpcevent(ctx, "brisinsold2::OnSold2On")

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Where am I?")
    |> mes("Isn't this...?!")
    |> next()
  end

  defp battle(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ah, I see.")
      |> mes("This must be the place where everything happened two years ago. Good, good...")
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("Shshh...")
      |> mes(
        "This is just a reflection of the past. Here, you'll see what happened at the time for yourself."
      )
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("It wasn't any trouble")
      |> mes("getting down here. But...")
      |> mes("We've got problems now.")
      |> next()
      |> mapannounce("que_god02", "D...Doppelganger!!!", 0, 10_288_896)

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What...?!")
      |> mes("Doppelganger?!")
      |> next()
      |> donpcevent("#brisinsummon::OnDoppel1On")
      |> donpcevent("#brisinsummon::OnKnight1On")
      |> donpcevent("#brisinsummon::OnKnight2On")
      |> donpcevent("#brisinsummon::OnKnight3On")
      |> donpcevent("#brisinsummon::OnLowenOn")

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What's going on?")
      |> mes("Did you really fight with that creature? H-hey! Answer me!")
      |> next()
      |> mes("[Lowen Ellenen]")
      |> mes("Yes, this was the place...")
      |> mes("The commander gave orders")
      |> mes("and then... What happened?")
      |> next()
      |> mapannounce("que_god02", "Everyone, stay calm! Get into your positions!", 0, 10_288_896)
      |> mes("^4E2F2F[Crusader Commander]")
      |> mes(
        "Everyone, get into your positions! Front line, block its movement! Rear line, support the defense!^000000"
      )

    ctx = emotion(ctx, :go, getnpcid(ctx, "#knight1"))
    ctx = emotion(ctx, :go, getnpcid(ctx, "#knight2"))
    ctx = emotion(ctx, :go, getnpcid(ctx, "#knight3"))

    ctx
    |> emotion(:surprise, getnpcid(ctx, "#doppelganger1"))
    |> next()
    |> mes("[Lowen Ellenen]")
    |> mes("N-no!")
    |> mes("I'm not running away!")
    |> next()
    |> mes(
      "^3355FFYou're filled with a great anxiety, and you experience for yourself the fear and pressure Lowen felt during those very moments.^000000"
    )
    |> next()
    |> mes("^4E2F2F[Crusader Commander]")
    |> mes("Go, Lowen!")
    |> mes("Cast Grand Cross, now!^000000")
    |> next()
    |> specialeffect(:beginspell7, :area, "#lowen")
    |> mapannounce("que_god02", "Mwahaha! Mortals are such fools...", 0, 11_053_224)
    |> donpcevent("#brisinsummon::OnDoppel1Off")
    |> donpcevent("#brisinsummon::OnDoppel2On")
  end

  defp aftermath(ctx) do
    ctx = emotion(ctx, :surprise, getnpcid(ctx, "#knight1"))
    ctx = emotion(ctx, :surprise, getnpcid(ctx, "#knight2"))
    ctx = emotion(ctx, :surprise, getnpcid(ctx, "#knight3"))
    ctx = emotion(ctx, :surprise, getnpcid(ctx, "#lowen"))

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(" ??!!!")
    |> next()
    |> specialeffect(:beginspell7, :area, "#doppelganger2")
    |> mes("[Male Voice]")
    |> mes("Lowen!")
    |> mes("Noooooooooo!!!")
    |> close2()
    |> warp("que_god02", 120, 52)
    |> donpcevent("#brisinsummon::OnDoppel2Off")
    |> donpcevent("#brisinsummon::OnKnight1Off")
    |> donpcevent("#brisinsummon::OnKnight2Off")
    |> donpcevent("#brisinsummon::OnKnight3Off")
    |> donpcevent("#brisinsummon::OnLowenOff")
  end
end
