defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.GreenWisemanStatue do
  @moduledoc """
  Advances the Thanatos seal using its corresponding charm stone.

  ## Behavior

  - Accepts its charm stone when the preceding seals have been released.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tha_t12",
        x: 154,
        y: 17,
        dir: 0,
        sprite: 111,
        name: "Green Wiseman Statue",
        scope: :shared,
        unique_name: "Green Wiseman Statue#tt"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_temp_var(ctx, "thana_summon", 0) != 1 ->
        ctx |> mes("The statue has such a strong light that I can't see or touch it.") |> close()

      count_item(ctx, 7429) <= 0 ->
        ctx
        |> mes("The statue give off mysterious light.")
        |> mes("Strange power has blocked your access.")
        |> close()

      true ->
        offer_stone(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_stone(ctx) do
    {ctx, choice} =
      ctx
      |> mes("A statue gives off green light.")
      |> mes("The wiseman's wand seems to be missing a gem.")
      |> mes("As I draw closer to the statue, the Green Charm Stone emits a bright light.")
      |> specialeffect(:beginspell4)
      |> specialeffect2(:beginspell4)
      |> next()
      |> select(["Insert the Green Charm Stone.", "Run away."])

    cond do
      choice == 2 ->
        close(ctx)

      get_server_temp_var(ctx, "thana_summon", 0) == 1 ->
        ctx
        |> mes("After inserting the Green Charm Stone into the wand, the statue begins to react.")
        |> specialeffect(:beginspell4)
        |> delitem(7429, 1)
        |> set_server_temp_var("thana_summon", 2)
        |> donpcevent("#tteffect02::OnEnable")
        |> mapannounce(
          "tha_t12",
          "The green magic power has released part of the seal.",
          1,
          "0x00ff00"
        )
        |> close()

      true ->
        ctx |> mes("Someone has already inserted a Charm Stone into this statue.") |> close()
    end
  end
end
