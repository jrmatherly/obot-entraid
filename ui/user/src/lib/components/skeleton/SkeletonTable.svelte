<script lang="ts">
	import { twMerge } from 'tailwind-merge';
	import Skeleton from './Skeleton.svelte';

	interface Props {
		rows?: number;
		columns?: number;
		showHeader?: boolean;
		class?: string;
	}

	let { rows = 5, columns = 4, showHeader = true, class: className }: Props = $props();
</script>

<div
	class={twMerge(
		'dark:bg-surface2 dark:border-surface3 overflow-hidden rounded-xl border bg-white shadow-sm',
		className
	)}
>
	{#if showHeader}
		<div class="dark:bg-surface3 flex gap-4 border-b bg-gray-50 p-4">
			{#each Array(columns) as _}
				<div class="flex-1">
					<Skeleton variant="text" width="60%" height="14px" />
				</div>
			{/each}
		</div>
	{/if}

	<div class="divide-y dark:divide-gray-700">
		{#each Array(rows) as _}
			<div class="flex items-center gap-4 p-4">
				{#each Array(columns) as _, colIndex}
					<div class="flex-1">
						{#if colIndex === 0}
							<div class="flex items-center gap-3">
								<Skeleton variant="avatar" width="32px" height="32px" />
								<Skeleton variant="text" width="70%" />
							</div>
						{:else}
							<Skeleton variant="text" width={`${60 + Math.random() * 30}%`} />
						{/if}
					</div>
				{/each}
			</div>
		{/each}
	</div>
</div>
