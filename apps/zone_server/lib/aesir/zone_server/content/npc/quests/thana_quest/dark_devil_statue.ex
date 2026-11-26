defmodule Aesir.ZoneServer.Content.Npc.Quests.ThanaQuest.DarkDevilStatue do
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
        x: 129,
        y: 86,
        dir: 0,
        sprite: 111,
        name: "Dark Devil Statue",
        scope: :shared,
        unique_name: "Dark Devil Statue#tt"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_temp_var(ctx, "thana_summon", 0) != 4 ->
        ctx |> mes("The statue has such a strong light that I can't see or touch it.") |> close()

      count_item(ctx, 7430) <= 0 ->
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
      |> mes("A devil statue emits dark light.")
      |> mes("The right eye seems to be missing a gem.")
      |> mes("As I draw closer to the statue, the Black Charm Stone emits a bright light.")
      |> specialeffect(:beginspell7)
      |> specialeffect2(:beginspell7)
      |> next()
      |> select(["Insert the Black Charm Stone.", "Run away."])

    cond do
      choice == 2 ->
        close(ctx)

      get_server_temp_var(ctx, "thana_summon", 0) == 4 ->
        ctx
        |> mes(
          "After inserting the Red Charm Stone into the eye socket, the statue begins to react."
        )
        |> specialeffect(:beginspell7)
        |> delitem(7430, 1)
        |> set_server_temp_var("thana_summon", 5)
        |> donpcevent("#gateto_thanatos::OnEnable")
        |> donpcevent("#tteffect01::OnStop")
        |> donpcevent("#tteffect02::OnStop")
        |> donpcevent("#tteffect03::OnStop")
        |> donpcevent("#tteffect04::OnStop")
        |> mapannounce(
          "tha_t12",
          "The Black Charm Stone's magic power has released the final seal.",
          1,
          "0x00ff00"
        )
        |> close()

      true ->
        ctx |> mes("Someone has already inserted a Charm Stone into this statue.") |> close()
    end
  end
end
