defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Box1925 do
  @moduledoc """
  A password-operated box supplies the Toy Key.

  ## Behavior

  - Checks inventory capacity before examining the box.
  - At the required quest stage, accepts the exact password and awards a key when none is held.

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
        map: "kh_kiehl01",
        x: 19,
        y: 25,
        dir: 0,
        sprite: 111,
        name: "Box",
        scope: :shared,
        unique_name: "Box#kh1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{7505, 1}]) == 0 -> inventory_full(ctx)
      get_char_var(ctx, :KielHyreQuest, 0) < 74 -> enter_password(ctx, false)
      count_item(ctx, 7505) < 1 -> enter_password(ctx, true)
      true -> ctx |> mes("^3355FFThis is where you") |> mes("found the Toy key^000000") |> close()
    end
  end

  defp enter_password(ctx, can_open?) do
    {ctx, password} =
      ctx
      |> mes("^3355FFYou found a box with")
      |> mes("a button for each letter")
      |> mes("of the alphabet on top of it.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHInput$", password)

    if can_open? and get_local(ctx, :"KHInput$", "") == "open the door" do
      reveal_key(ctx)
    else
      ctx |> mes("^3355FFNothing happened.^000000") |> close()
    end
  end

  defp inventory_full(ctx) do
    ctx
    |> mes("^3355FFJust a second...")
    |> mes("You're carrying too")
    |> mes("many items with you")
    |> mes("right now, so you'll")
    |> mes("need to free up more")
    |> mes("Inventory space first...^000000")
    |> close()
  end

  defp reveal_key(ctx) do
    ctx
    |> mes("^3355FFAs soon as you enter the")
    |> mes("password, the nearby door")
    |> mes("emits a pleasant chiming")
    |> mes("sound, and the box pops")
    |> mes("open to reveal a small key.^000000")
    |> give_item(7505, 1)
    |> close()
  end
end
