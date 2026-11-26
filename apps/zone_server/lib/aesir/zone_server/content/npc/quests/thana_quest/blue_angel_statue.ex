defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.BlueAngelStatue do
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
        x: 103,
        y: 17,
        dir: 0,
        sprite: 111,
        name: "Blue Angel Statue",
        scope: :shared,
        unique_name: "Blue Angel Statue#tt"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_temp_var(ctx, "thana_summon", 0) != 2 ->
        ctx |> mes("The statue has such a strong light that I can't see or touch it.") |> close()

      count_item(ctx, 7428) <= 0 ->
        ctx
        |> mes("The statue give off mysterious light.")
        |> mes("Strange power has blocked you to access.")
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
      |> mes("An angel statue is covered with a blue light.")
      |> mes("A gem seems to be missing from the statue's belt.")
      |> mes("As I draw closer to the statue, the Blue Charm Stone emits a bright light.")
      |> specialeffect(:beginspell2)
      |> specialeffect2(:beginspell2)
      |> next()
      |> select(["Insert the Blue Charm Stone.", "Run away."])

    cond do
      choice == 2 ->
        close(ctx)

      get_server_temp_var(ctx, "thana_summon", 0) == 2 ->
        ctx
        |> mes("After inserting the Blue Charm Stone into the belt, the statue begins to react.")
        |> specialeffect(:beginspell2)
        |> delitem(7428, 1)
        |> set_server_temp_var("thana_summon", 3)
        |> donpcevent("#tteffect03::OnEnable")
        |> mapannounce(
          "tha_t12",
          "The blue magic power has released part of the seal.",
          1,
          "0x00ff00"
        )
        |> close()

      true ->
        ctx |> mes("Someone has already inserted a Charm Stone into this statue.") |> close()
    end
  end
end
