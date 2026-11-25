defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Switch do
  @moduledoc """
  Lets the player overhear a secret meeting.

  ## Behavior

  - Advances the investigation if the player listens.

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
        x: 173,
        y: 167,
        dir: 1,
        sprite: 111,
        name: "Switch",
        scope: :shared,
        trigger: {2, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx), do: overhear(ctx)

  @impl true
  def on_talk(ctx), do: overhear(ctx)

  defp overhear(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) == 1 do
      ctx =
        ctx
        |> mes("[??????]")
        |> mes("^666666Come on.")
        |> mes("This way.^000000")
        |> next()
        |> mes("[??????]")
        |> mes("^333333Hurry up, before")
        |> mes("the others see you...^000000")
        |> next()

      {ctx, choice} =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("(Wait a second...")
        |> mes("That voice is")
        |> mes("awfully familiar.)")
        |> next()
        |> select(["Ignore it.", "Keep listening."])

      case choice do
        1 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("(That voice is")
          |> mes("awfully familiar...")
          |> mes("But what do I care?)")
          |> close()

        2 ->
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("(This is too weird.")
          |> mes("I guess I better keep")
          |> mes("listening to see what")
          |> mes("I can learn about this...)")
          |> next()
          |> mes("[??????]")
          |> mes("^333333So why did you tell")
          |> mes("me to come to such")
          |> mes("a dangerous place...?^000000")
          |> next()
          |> mes("^3355FFThat's...^000000")
          |> mes("That's ^660000Ghalstein's^3355FF voice!^000000")
          |> next()
          |> mes("[????]")
          |> mes("^666666Something unexpected")
          |> mes("came up. Hence the sudden")
          |> mes("change in plans. Now listen...^000000")
          |> next()
          |> mes("^3355FFSuddenly, both of the")
          |> mes("voices grew much quieter")
          |> mes("as the two men spoke to each")
          |> mes("other in low, hoarse whispers")
          |> mes("that are almost inaudible.^000000")
          |> next()
          |> mes("[????]")
          |> mes("^666666....")
          |> mes("...Relate.....")
          |> mes("...Business.....Kafr...^000000")
          |> next()
          |> mes("[Ghalstein]")
          |> mes("^333333Oh. That does")
          |> mes("sound very urgent.")
          |> mes("But it's not safe to")
          |> mes("talk about this here.")
          |> mes("Let's move somewhere")
          |> mes("a little more secure.^000000")
          |> next()
          |> mes("[????]")
          |> mes("^666666No problem.")
          |> mes("........................^000000")
          |> next()
          |> mes("........................")
          |> mes(".....................")
          |> mes("..................")
          |> next()
          |> mes("^3355FFThat other voice...")
          |> mes("Whoever it belonged")
          |> mes("to is gone! What's")
          |> mes("going on here?^000000")
          |> set_char_var(:lhz_boss, 2)
          |> setquest(12_015)
          |> close()

        _ ->
          ctx
      end
    else
      ctx
    end
  end
end
