defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz07 do
  @moduledoc """
  A cursed spirit reveals a memory of the city.

  ## Behavior

  - Shows a memory and advances the curse at the appropriate stage.

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
        x: 113,
        y: 150,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz07",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 do
      case get_char_var(ctx, :lhz_curse, 0) do
        0 -> sc_start(ctx, :sc_curse, 1000, 0)
        curse when curse > 0 and curse < 26 -> witness_memory(ctx)
        _ -> ctx
      end
    else
      ctx
    end
  end

  defp witness_memory(ctx) do
    ctx =
      ctx
      |> mes("............")
      |> next()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_start(:sc_blind, 60_000, 0)
      |> mes("............")
      |> next()
      |> mes("[?????]")
      |> mes("So, what exactly did you")
      |> mes("want me to do? I'm sorry,")
      |> mes("I wasn't able to gather my")
      |> mes("actual job function from")
      |> mes("the presentation...")
      |> next()
      |> mes("[???]")
      |> mes("Hee hee hee~")
      |> mes("Don't worry about it.")
      |> mes("Just relax and stay")
      |> mes("right where you are.")
      |> next()
      |> mes("[?????]")
      |> mes("Mmm. Alright.")
      |> mes("I just thought that I was")
      |> mes("supposed to go somewhere,")
      |> mes("that's all. Um, shouldn't")
      |> mes("I be getting ready...?")
      |> next()
      |> mes("[???]")
      |> mes("Oh, don't worry about")
      |> mes("that, either. All of the")
      |> mes("arrangements will be")
      |> mes("taken care of. You'll")
      |> mes("be taken to that far")
      |> mes("off place very soon...")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> close2()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_end(:sc_blind)
      |> sc_start(:sc_curse, 3000, 0)

    if get_char_var(ctx, :lhz_curse, 0) == 6 do
      set_char_var(ctx, :lhz_curse, 7)
    else
      ctx
    end
  end
end
