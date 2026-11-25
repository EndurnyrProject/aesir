defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.OldMan do
  @moduledoc """
  An old man recommends helping Kazien with his business.

  ## Behavior

  - Starts the delivery job quest when the player has not begun it.

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
        map: "lighthalzen",
        x: 141,
        y: 162,
        dir: 3,
        sprite: 85,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#reken"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Old Man]")
      |> mes("Lately, Kazien seems")
      |> mes("to be having a hard time")
      |> mes("managing his business.")
      |> mes("Always complaining that")
      |> mes("he lacks the manpower...")
      |> next()
      |> mes("[Old Man]")
      |> mes("I don't know what kind of")
      |> mes("business he's conducting,")
      |> mes("but why don't you help him")
      |> mes("out? I don't believe that any")
      |> mes("particularly special skills are")
      |> mes("required for some positions.")
      |> next()

    ctx =
      if not Rathena.truthy?(get_char_var(ctx, :lhz_rekenber, 0)) do
        ctx |> set_char_var(:lhz_rekenber, 1) |> setquest(12_007)
      else
        ctx
      end

    ctx
    |> mes("[Old Man]")
    |> mes("Well, if you're interested,")
    |> mes("you can find Kazien inside")
    |> mes("the corporation building.")
    |> mes("Young people like him should")
    |> mes("never be too proud to ask for help. He still needs to learn...")
    |> close()
  end
end
