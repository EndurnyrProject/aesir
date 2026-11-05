defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.HeavyDoorHeavydoorkhq2 do
  @moduledoc """
  These heavy doors resist attempts to push them open.

  ## Behavior

  - Offers an attempt to open the door during the factory investigation, but never opens it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_dun01",
        x: 76,
        y: 233,
        dir: 0,
        sprite: 111,
        name: "Heavy Door::HeavyDoorKHQ2",
        scope: :shared,
        unique_name: "HeavyDoorKHQ2"
      },
      %{
        map: "kh_dun01",
        x: 106,
        y: 233,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh3"
      },
      %{
        map: "kh_dun01",
        x: 6,
        y: 164,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh4"
      },
      %{
        map: "kh_dun01",
        x: 6,
        y: 133,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh5"
      },
      %{
        map: "kh_dun01",
        x: 6,
        y: 60,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh6"
      },
      %{
        map: "kh_dun01",
        x: 6,
        y: 30,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh7"
      },
      %{
        map: "kh_dun01",
        x: 6,
        y: 18,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh8"
      },
      %{
        map: "kh_dun01",
        x: 235,
        y: 70,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh9"
      },
      %{
        map: "kh_dun01",
        x: 235,
        y: 92,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh10"
      },
      %{
        map: "kh_dun01",
        x: 235,
        y: 114,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "Heavy Door#kh11"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    if quest_stage >= 38 and quest_stage < 46 do
      try_door(ctx)
    else
      ctx
      |> mes("^3355FFThere is a large, heavy")
      |> mes("door infront of you^000000")
      |> close()
    end
  end

  defp try_door(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere is a large, heavy")
      |> mes("door infront of you.^000000")
      |> next()
      |> select(["Open Door", "Cancel"])

    case choice do
      1 ->
        {ctx, answer} = input(ctx, :string)

        ctx
        |> set_local(:"KHInput$", answer)
        |> mes("^3355FFYou try to push the")
        |> mes("door open with all")
        |> mes("your might, but fail")
        |> mes("to make it budge.^000000")
        |> close()

      2 ->
        ctx
        |> mes("^3355FFyou decided to leave")
        |> mes("this door alone until")
        |> mes("you can figure out")
        |> mes("how to open it^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
