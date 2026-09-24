defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesAldebaran.Soldier133108 do
  @moduledoc """
  Al De Baran guard who points visitors toward local facilities.

  ## Behavior

  - Marks a selected facility on the mini-map or offers a farewell.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets
    - erKURITA
    - Silent
    - Samuray22
    - Playtester

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "aldebaran",
        x: 133,
        y: 108,
        dir: 4,
        sprite: 105,
        name: "Soldier",
        scope: :pre_renewal,
        unique_name: "Soldier#2alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("prt_soldier", 2)
      |> mes("[Al De Baran Guard]")
      |> mes("I'm just an")
      |> mes("ordinary guard,")
      |> mes("the kind you can")
      |> mes("find in any other city.")
      |> next()
      |> mes("[Al De Baran Guard]")
      |> mes("When I'm not too busy")
      |> mes("protecting the Al De Baran")
      |> mes("populace, I'm here giving directions to adventurers")
      |> mes("like yourself.")
      |> next()
      |> select([
        "Kafra Main Office ",
        "Weapon Shop ",
        "Sorcerer Guild ",
        "Pub ",
        "Item Shop ",
        "Alchemist Guild ",
        "End Conversation "
      ])

    ctx =
      case choice do
        1 ->
          ctx
          |> viewpoint(1, 61, 229, 0, 0xFF6633)
          |> mes("^FF6633+^000000 -> Kafra Main Office ")

        2 ->
          ctx |> viewpoint(1, 72, 197, 1, 0x0000FF) |> mes("^0000FF+^000000 -> Weapon Shop ")

        3 ->
          ctx
          |> viewpoint(1, 223, 222, 2, 0x00FFFF)
          |> mes("^00FFFF+^000000 -> Sorcerer Guild (Closed)")

        4 ->
          ctx |> viewpoint(1, 233, 105, 3, 0x515151) |> mes("^515151+^000000 -> Pub ")

        5 ->
          ctx |> viewpoint(1, 197, 70, 4, 0x3355FF) |> mes("^3355FF+^000000 -> Item Shop ")

        6 ->
          ctx |> viewpoint(1, 60, 60, 5, 0xFF5555) |> mes("^FF5555+^000000 -> Alchemist Guild")

        7 ->
          ctx
          |> mes("[Al De Baran Guard]")
          |> mes("We are sworn to")
          |> mes("protect Al De Baran!")
          |> mes("May the forces of good")
          |> mes("always prevail over evil~")

        _ ->
          ctx
      end

    ctx |> close() |> cutin("prt_soldier", 255)
  end
end
