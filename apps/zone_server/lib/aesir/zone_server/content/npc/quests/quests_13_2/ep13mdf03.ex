defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13mdf03 do
  @moduledoc """
  Provides a fruit for the Yggdrasilberry quest.

  ## Behavior

  - Awards fruit at the appropriate quest stage and advances progression.
  - A repeat search can yield an apple, an insect bite, or nothing.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild01",
        x: 329,
        y: 29,
        dir: 0,
        sprite: 844,
        name: "???",
        scope: :shared,
        unique_name: "???#ep13mdf03"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        ctx
        |> mes("Wait a moment!!")
        |> mes("You have too many items.")
        |> mes("You can't receive this.")
        |> mes("Lighten your weight and")
        |> mes("try again.")
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) == 16 ->
        ctx =
          ctx
          |> mes("There's some kind of fruit lying on the ground.")
          |> mes("I see a small berry inside of a big outer shell...")
          |> mes("It is a Yggdrasil!")
          |> set_char_var(:ep13_mdrama, 17)
          |> give_item(607, 1)
          |> give_item(522, 1)
          |> changequest(7063, 7064)
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Arc gave me three Yggdrasilberries and...")
        |> mes("I've found... three. Six of them should be enough.")
        |> mes("Let's go back to Snorren.")
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) == 17 ->
        search_again(ctx)

      get_char_var(ctx, :ep13_mdrama, 0) > 17 ->
        ctx |> mes("There's only an empty shell left.") |> close()

      true ->
        ctx
        |> mes("A huge fruit is here.")
        |> mes("I don't know what kind of fruit it is.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp search_again(ctx) do
    ctx =
      ctx
      |> mes("I've already pulled out a Yggdradsil... but is there anyting else..?")
      |> next()
      |> set_local(:apple, Enum.random(1..100))

    cond do
      get_local(ctx, :apple, 0) < 50 ->
        ctx
        |> mes("I've been bitten by an unknown insect.")
        |> mes("It hurts!")
        |> percent_heal(hp: -30, sp: 0)
        |> close()

      get_local(ctx, :apple, 0) == 50 ->
        ctx |> mes("I found an apple.") |> give_item(512, 1) |> close()

      true ->
        ctx |> mes("There's nothing else.") |> close()
    end
  end
end
