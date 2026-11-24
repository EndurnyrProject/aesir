defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Iara do
  @moduledoc """
  Iara rewards purification and curses adventurers without a potion.

  ## Behavior

  - Consumes a purification potion to grant mode-dependent buffs and food effects.
  - Inflicts a random curse or confusion on adventurers without a potion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_dun02",
        x: 157,
        y: 74,
        dir: 5,
        sprite: 478,
        name: "Iara",
        scope: :shared,
        unique_name: "Iara#nk",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    if count_item(ctx, 11_517) < 1, do: curse(ctx), else: ctx
  end

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 11_517) > 0 do
      {ctx, choice} =
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Should I use a Purification Potion?")
        |> next()
        |> select(["Yes.", "No."])

      case choice do
        1 ->
          ctx =
            ctx
            |> specialeffect(:mappillar)
            |> mes("[Iara]")
            |> mes("Ah...this light is...")
            |> mes("It's like getting cleansed of evil thoughts")
            |> mes("from deep within my heart.")
            |> next()
            |> mes("[Iara]")
            |> mes(
              "At last I can forget the curse that I placed on myself when I drowned in the water."
            )
            |> next()
            |> mes("[Iara]")
            |> mes("Do you think I can be born again as a kind water nymph?")
            |> next()
            |> specialeffect(:ghost)
            |> mes("[Iara]")
            |> mes("Ah... Thank you for helping me recover my consciousness for a while.")
            |> mes("But... I think that the curse has been with me too long.")
            |> mes("Get away from me quickly.")
            |> delitem(11_517, 1)

          ctx =
            if Rathena.truthy?(checkre(ctx, 0)) do
              ctx
              |> percent_heal(hp: 100, sp: 100)
              |> sc_start(:sc_incflee, 3_600_000, 20)
              |> sc_start(:sc_inccri, 3_600_000, 10)
            else
              sc_start(ctx, :sc_inccri, 3_600_000, 7)
            end

          ctx
          |> consumeitem(12_043)
          |> consumeitem(12_063)
          |> consumeitem(12_058)
          |> consumeitem(12_053)
          |> consumeitem(12_048)
          |> consumeitem(12_068)
          |> next()
          |> mes("[Iara]")
          |> mes("Ahhh~...")
          |> specialeffect(:devil)
          |> next()
          |> mes("[Iara]")
          |> mes("The curse is too strong for me to keep contained.")
          |> mes("Leave now while you are safe.")
          |> close()

        2 ->
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("(I guess I should ignore her.)")
          |> close()

        _ ->
          ctx
      end
    else
      curse(ctx)
    end
  end

  defp curse(ctx) do
    ctx =
      ctx
      |> mes("[Iara]")
      |> mes("Aaaaaaaaaaaaaaaaaaaaaah.")
      |> mes("Eeeeeeeeeeeeeeeeeeeh.")
      |> mes("Oooooooooooooooooh.")

    ctx =
      if Enum.random(1..2) == 1 do
        sc_start(ctx, :sc_curse, 60_000, 0)
      else
        sc_start(ctx, :sc_confusion, 60_000, 0)
      end

    ctx
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ugh! What's this strange voice?")
    |> close()
  end
end
