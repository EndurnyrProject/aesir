defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Flashback2 do
  @moduledoc """
  A flashback recalls Kazien defending his choices.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 75,
        y: 248,
        dir: 3,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#flashback2",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :lhz_rekenber, 0) == 22 do
      ctx =
        ctx
        |> cutin("lhz_kaz11", 2)
        |> mes("[Kazien]")
        |> mes("Look man, this is what")
        |> mes("I decided. I don't care")
        |> mes("what other people'll think.")
        |> mes("I might go to hell when")
        |> mes("I die, but that's my problem.")
        |> next()
        |> mes("[Kazien]")
        |> mes("Besides, you adventurers")
        |> mes("are always running around")
        |> mes("with your swords and magic spells... Isn't that just as bad?")
        |> mes("It's not the weapons or the power that's bad: it's how they're used.")
        |> next()
        |> mes("[Kazien]")
        |> mes("There'd be days when my")
        |> mes("brother and I'd have nothing")
        |> mes("to eat. So when I heard about")
        |> mes("this job, I took it. What good")
        |> mes("is world peace if I'm not even")
        |> mes("alive to enjoy it, huh?")
        |> next()
        |> set_char_var(:lhz_rekenber, 23)
        |> cutin("", 255)

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("......")
      |> mes(".........")
      |> mes("Damn it!")
      |> close()
    else
      ctx
    end
  end
end
