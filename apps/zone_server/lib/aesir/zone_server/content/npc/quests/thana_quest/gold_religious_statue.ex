defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.GoldReligiousStatue do
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
        x: 161,
        y: 57,
        dir: 0,
        sprite: 111,
        name: "Gold Religious Statue",
        scope: :shared,
        unique_name: "Gold Religious Statue#tt"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_temp_var(ctx, "thana_summon", 0) != 0 ->
        ctx |> mes("The statue has such a strong light that I can't see or touch it.") |> close()

      count_item(ctx, 7427) <= 0 ->
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
      |> mes("It's a statue giving off a golden light.")
      |> mes("The sword appears to be missing a gem.")
      |> mes("As I draw closer to the statue, the Yellow Charm Stone emits a bright light.")
      |> specialeffect(:beginspell5)
      |> specialeffect2(:beginspell5)
      |> next()
      |> select(["Insert the Yellow Charm Stone.", "Run away."])

    cond do
      choice == 2 ->
        close(ctx)

      get_server_temp_var(ctx, "thana_summon", 0) == 0 ->
        ctx
        |> mes(
          "After inserting the Yellow Charm Stone into the sword, the statue begins to react."
        )
        |> specialeffect(:beginspell5)
        |> delitem(7427, 1)
        |> set_server_temp_var("thana_summon", 1)
        |> donpcevent("#tteffect01::OnEnable")
        |> mapannounce(
          "tha_t12",
          "The golden magic power has released part of the seal.",
          1,
          "0x00ff00"
        )
        |> close()

      true ->
        ctx |> mes("Someone has already inserted a Charm Stone into this statue.") |> close()
    end
  end
end
