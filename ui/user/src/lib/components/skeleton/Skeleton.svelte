<script lang="ts">
	import { twMerge } from 'tailwind-merge';

	type SkeletonVariant = 'text' | 'circular' | 'rectangular' | 'card' | 'avatar' | 'button';

	interface Props {
		variant?: SkeletonVariant;
		width?: string;
		height?: string;
		lines?: number;
		class?: string;
		animate?: boolean;
	}

	let {
		variant = 'text',
		width,
		height,
		lines = 1,
		class: className,
		animate = true
	}: Props = $props();

	const baseClasses = 'bg-gray-200 dark:bg-gray-700';
	const animationClasses = $derived(animate ? 'animate-pulse' : '');

	const variantClasses: Record<SkeletonVariant, string> = {
		text: 'h-4 rounded',
		circular: 'rounded-full',
		rectangular: 'rounded-lg',
		card: 'rounded-xl',
		avatar: 'size-10 rounded-full',
		button: 'h-10 rounded-lg'
	};

	const defaultDimensions: Record<SkeletonVariant, { width?: string; height?: string }> = {
		text: { width: '100%', height: undefined },
		circular: { width: '40px', height: '40px' },
		rectangular: { width: '100%', height: '100px' },
		card: { width: '100%', height: '200px' },
		avatar: { width: '40px', height: '40px' },
		button: { width: '100px', height: undefined }
	};

	const computedWidth = $derived(width ?? defaultDimensions[variant].width);
	const computedHeight = $derived(height ?? defaultDimensions[variant].height);
</script>

{#if variant === 'text' && lines > 1}
	<div class={twMerge('flex flex-col gap-2', className)}>
		{#each Array(lines) as _, i (i)}
			<div
				class={twMerge(baseClasses, animationClasses, variantClasses[variant])}
				style:width={i === lines - 1 ? '75%' : computedWidth}
				style:height={computedHeight}
			></div>
		{/each}
	</div>
{:else}
	<div
		class={twMerge(baseClasses, animationClasses, variantClasses[variant], className)}
		style:width={computedWidth}
		style:height={computedHeight}
	></div>
{/if}
