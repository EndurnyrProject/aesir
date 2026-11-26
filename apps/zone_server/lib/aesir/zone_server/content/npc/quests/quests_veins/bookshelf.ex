defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Bookshelf do
  @moduledoc """
  A bookshelf holds reports and a reward for the volcano investigation.

  ## Behavior

  - Supplies the report and later awards a random item and experience.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 281,
        y: 214,
        dir: 3,
        sprite: 111,
        name: "Bookshelf",
        scope: :shared,
        unique_name: "Bookshelf#vol"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 8 and count_item(ctx, 7342) == 0 ->
        ctx
        |> mes("^3355FFYou find a bundle")
        |> mes("of reports carelessly")
        |> mes("stuck between some")
        |> mes("books on this bookshelf.^000000")
        |> give_item(7342, 1)
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 25 ->
        claim_reward(ctx)

      true ->
        ctx |> describe_books() |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_books(ctx) do
    ctx
    |> mes("^3355FFThere's a lot of")
    |> mes("scattered books and")
    |> mes("notebooks lying on")
    |> mes("this bookshelf.^000000")
  end

  defp claim_reward(ctx) do
    ctx =
      ctx
      |> describe_books()
      |> next()
      |> mes("^3355FFAfter a quick look,")
      |> mes("you notice the grayish")
      |> mes("purple box that Gio was")
      |> mes("talking about it. You close")
      |> mes("your eyes, and reach inside")
      |> mes("Gio's purple box of goodies.^000000")
      |> next()
      |> changequest(60212, 60213)
      |> set_char_var(:aru_vol, 26)
      |> set_local(:box_box, Enum.random(1..20))

    roll = get_local(ctx, :box_box, 0)

    ctx =
      cond do
        roll < 7 -> give_item(ctx, 12104, 1)
        roll < 9 -> give_item(ctx, 661, 1)
        roll < 20 -> give_item(ctx, 12027, 5)
        true -> give_item(ctx, 12103, 1)
      end

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 100_000, else: 800_000), 0)
    |> mes("^3355FFWell, you've done all")
    |> mes("that you could here.")
    |> mes("Now would be a good time")
    |> mes("to return to High Priest Zhed.^000000")
    |> close()
  end
end
