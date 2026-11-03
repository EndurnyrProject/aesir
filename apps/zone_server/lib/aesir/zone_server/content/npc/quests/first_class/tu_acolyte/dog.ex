defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuAcolyte.Dog do
  @moduledoc """
  The lost dog Sister Asthe cares for in the convent cemetery.

  ## Behavior

  - On the dog-feeding step of the Acolyte training quest, lets the player give treats or pet
    the dog over and over; after more than four treats in one visit the dog growls. The menu
    keeps repeating until the player leaves the dialog.
  - Otherwise the dog just barks and the player admires it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Capuche
    - Euphy
    - Daegaladh
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_monk",
        x: 235,
        y: 245,
        dir: 5,
        sprite: 81,
        name: "Dog",
        scope: :shared,
        unique_name: "Dog#tu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Dog]")
      |> mes("^CDB79EBark bark!")
      |> mes("Woof woof!^000000")
      |> next()

    ctx = if get_char_var(ctx, :tu_acolyte01, 0) == 10, do: play_with_dog(ctx), else: ctx

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("So cute~!")
    |> close()
  end

  defp play_with_dog(ctx) do
    {ctx, action} = select(ctx, ["Give a treat.", "Pet the dog.", "End actions."])

    ctx =
      case action do
        1 -> give_treat(ctx)
        2 -> ctx |> mes("[Dog]") |> mes("^CDB79ERoof roof~^000000") |> emotion(:throb)
        3 -> ctx |> mes("[Dog]") |> mes("^CDB79ERoof roof!^000000")
        _ -> ctx
      end

    ctx
    |> next()
    |> play_with_dog()
  end

  defp give_treat(ctx) do
    ctx = set_local(ctx, :dog_food, get_local(ctx, :dog_food, 0) + 1)

    if get_local(ctx, :dog_food, 0) > 4 do
      ctx
      |> mes("[Dog]")
      |> mes("^CDB79EGrrrrrr...!^000000")
      |> emotion(:fret)
      |> next()
      |> mes("^3355FFThe dog grinds")
      |> mes("its teeth and glares")
      |> mes("at you menacingly.^000000")
    else
      ctx
      |> mes("[Dog]")
      |> mes("^CDB79ERoof roof!^000000")
      |> emotion(:throb)
    end
  end
end
