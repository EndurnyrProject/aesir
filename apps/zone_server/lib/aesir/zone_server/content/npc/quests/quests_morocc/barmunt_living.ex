defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.BarmuntLiving do
  @moduledoc """
  A vision reveals a confrontation between a mysterious man and woman.

  ## Behavior

  - The woman transforms into a crow before the player returns to the library.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "que_ba",
        x: 270,
        y: 270,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#barmunt_living",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx), do: witness_confrontation(ctx)
  @impl true
  def on_talk(ctx) do
    witness_confrontation(ctx)
  end

  defp witness_confrontation(ctx) do
    ctx =
      ctx
      |> mes("..................")
      |> mes("..................")
      |> mes("..................")
      |> mes("..................")
      |> next()
      |> mes("[Mysterious Man]")
      |> mes("..................")
      |> mes("..................")
      |> mes("..................")
      |> mes("E...Eva, no!")
      |> next()
      |> mes("[Mysterious Man]")
      |> mes("Was it a dream?")
      |> mes("..................")
      |> mes("...Gosh, that was strange.")
      |> next()
      |> mes("[Mysterious Man]")
      |> mes("Mother was... She was a regular human.")
      |> mes("Was I standing next to her?")
      |> mes("..................")
      |> next()
      |> mes(
        "^660000He mumbled to himself, and brushed back his sweaty hair with a trembling hand.^000000"
      )
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("A dream again.")
      |> mes("I guess he won't be able to see or hear me, just like the others.")
      |> next()
      |> mes("^660000You put your guard down, and stare at him.")
      |> mes("Suddenly his face distorted in anger as he looked right back at you.^000000")
      |> next()
      |> mes("[Mysterious Man]")
      |> mes("How the hell did you find me?!")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Wah! He can see me! He can see me!")
    |> next()
    |> enablenpc("#barmut_onna")
    |> mes("[Mysterious Woman]")
    |> mes("You don't have to be so angry at me, sir.")
    |> next()
    |> mes("^660000As soon as you heard her voice,")
    |> mes("you turned around and found a woman standing there.^000000")
    |> next()
    |> mes("[Mysterious Woman]")
    |> mes(
      "It was almost done, but then you broke all of them -- even ^FF00FFBEEP^000000 and ^FF00FFBEEP^000000 -- and were hiding in here."
    )
    |> next()
    |> mes("[Mysterious Man]")
    |> mes("They weren't supposed to exist in this world!")
    |> next()
    |> mes("[Mysterious Woman]")
    |> mes("It's his decision. Your fate is on his...")
    |> next()
    |> mes("[Mysterious Man]")
    |> mes("Shut up!")
    |> next()
    |> mes(
      "^660000The raging man drew a sword, and pointed it at her. She then suddenly transformed into a crow and flew away. The echos of her laughter could be heard outside the window.^000000"
    )
    |> disablenpc("#barmut_onna")
    |> specialeffect(:bat)
    |> next()
    |> mes("[Echoing Voice]")
    |> mes("You are bound to your fate, no matter how hard you try to escape...")
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> next()
    |> mes("..................")
    |> mes("..................")
    |> mes("..................")
    |> mes("..................")
    |> next()
    |> mes("..................")
    |> mes("..................")
    |> mes("..................")
    |> mes("..................")
    |> close2()
    |> warp("yuno_in04", 165, 122)
  end
end
